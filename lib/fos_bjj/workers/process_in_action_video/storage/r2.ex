defmodule FosBjj.Workers.ProcessInActionVideo.Storage.R2 do
  @moduledoc """
  Cloudflare R2 storage for processed inAction videos.

  R2 exposes an S3-compatible API. This module signs a simple PUT request with
  AWS Signature Version 4 and sends it with Req, avoiding an additional S3 client
  dependency.
  """

  @behaviour FosBjj.Workers.ProcessInActionVideo.Storage

  @algorithm "AWS4-HMAC-SHA256"
  @region "auto"
  @service "s3"
  @default_cache_control "public, max-age=31536000, immutable"
  @default_content_type "video/mp4"

  @impl true
  def store(path, storage_key, opts \\ []) do
    with {:ok, config} <- config(),
         {:ok, body} <- File.read(path) do
      request = signed_upload_request(config, storage_key, body, opts, DateTime.utc_now())

      case http_client().request(
             method: :put,
             url: request.url,
             headers: request.headers,
             body: body
           ) do
        {:ok, %{status: status}} when status >= 200 and status < 300 ->
          {:ok, public_url(config.public_base_url, storage_key), storage_key}

        {:ok, %{status: status, body: response_body}} ->
          {:error, {:r2_upload_failed, status, response_body}}

        {:error, reason} ->
          {:error, {:r2_upload_failed, reason}}
      end
    end
  end

  @impl true
  def cleanup_after_store?, do: true

  @doc false
  def signed_upload_request(config, storage_key, body, opts \\ [], now \\ DateTime.utc_now()) do
    config = normalize_config(config)
    endpoint = String.trim_trailing(config.endpoint, "/")
    uri = URI.parse(endpoint)
    host = uri.host || raise ArgumentError, "R2 endpoint must include a host"

    canonical_uri = canonical_uri(config.bucket, storage_key)
    url = endpoint <> canonical_uri
    payload_hash = sha256_hex(body)
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    date = Calendar.strftime(now, "%Y%m%d")
    credential_scope = Enum.join([date, @region, @service, "aws4_request"], "/")

    headers_for_signing = %{
      "cache-control" => Keyword.get(opts, :cache_control, @default_cache_control),
      "content-type" => Keyword.get(opts, :content_type, @default_content_type),
      "host" => host,
      "x-amz-content-sha256" => payload_hash,
      "x-amz-date" => amz_date
    }

    {canonical_headers, signed_headers} = canonical_headers(headers_for_signing)

    canonical_request =
      [
        "PUT",
        canonical_uri,
        "",
        canonical_headers,
        signed_headers,
        payload_hash
      ]
      |> Enum.join("\n")

    string_to_sign =
      [
        @algorithm,
        amz_date,
        credential_scope,
        sha256_hex(canonical_request)
      ]
      |> Enum.join("\n")

    signature = signing_key(config.secret_access_key, date) |> hmac(string_to_sign) |> hex()

    authorization =
      "#{@algorithm} Credential=#{config.access_key_id}/#{credential_scope}, " <>
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"

    %{
      url: url,
      headers: [
        {"Authorization", authorization},
        {"Cache-Control", headers_for_signing["cache-control"]},
        {"Content-Type", headers_for_signing["content-type"]},
        {"Host", host},
        {"x-amz-content-sha256", payload_hash},
        {"x-amz-date", amz_date}
      ],
      canonical_request: canonical_request,
      signed_headers: signed_headers
    }
  end

  defp http_client do
    Application.get_env(:fos_bjj, :in_action_video_r2_http_client, Req)
  end

  defp config do
    raw_config = Application.get_env(:fos_bjj, :in_action_video_r2, [])
    config = normalize_config(raw_config)

    missing =
      [:endpoint, :bucket, :access_key_id, :secret_access_key, :public_base_url]
      |> Enum.filter(fn key -> blank?(Map.get(config, key)) end)

    case missing do
      [] -> {:ok, config}
      missing -> {:error, {:missing_r2_config, missing}}
    end
  end

  defp normalize_config(config) when is_map(config) do
    account_id = config[:account_id] || config["account_id"]

    %{
      account_id: account_id,
      endpoint: config[:endpoint] || config["endpoint"] || default_endpoint(account_id),
      bucket: config[:bucket] || config["bucket"],
      access_key_id: config[:access_key_id] || config["access_key_id"],
      secret_access_key: config[:secret_access_key] || config["secret_access_key"],
      public_base_url: config[:public_base_url] || config["public_base_url"]
    }
  end

  defp normalize_config(config) when is_list(config),
    do: config |> Map.new() |> normalize_config()

  defp default_endpoint(nil), do: nil
  defp default_endpoint(""), do: nil
  defp default_endpoint(account_id), do: "https://#{account_id}.r2.cloudflarestorage.com"

  defp public_url(public_base_url, storage_key) do
    public_base_url = String.trim_trailing(public_base_url, "/")
    storage_key = String.trim_leading(storage_key, "/")

    "#{public_base_url}/#{storage_key}"
  end

  defp canonical_uri(bucket, storage_key) do
    segments = [bucket | String.split(storage_key, "/", trim: true)]

    "/" <> Enum.map_join(segments, "/", &uri_encode/1)
  end

  defp uri_encode(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)

  defp canonical_headers(headers) do
    sorted_headers =
      headers
      |> Enum.map(fn {key, value} -> {String.downcase(key), normalize_header_value(value)} end)
      |> Enum.sort_by(fn {key, _value} -> key end)

    canonical =
      sorted_headers
      |> Enum.map(fn {key, value} -> "#{key}:#{value}\n" end)
      |> Enum.join()

    signed =
      sorted_headers
      |> Enum.map_join(";", fn {key, _value} -> key end)

    {canonical, signed}
  end

  defp normalize_header_value(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp signing_key(secret_access_key, date) do
    ("AWS4" <> secret_access_key)
    |> hmac(date)
    |> hmac(@region)
    |> hmac(@service)
    |> hmac("aws4_request")
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp sha256_hex(data), do: :crypto.hash(:sha256, data) |> hex()
  defp hex(data), do: Base.encode16(data, case: :lower)

  defp blank?(value), do: is_nil(value) or value == ""
end
