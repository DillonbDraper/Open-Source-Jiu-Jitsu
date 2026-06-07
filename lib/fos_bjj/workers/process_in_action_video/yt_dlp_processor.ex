defmodule FosBjj.Workers.ProcessInActionVideo.YtDlpProcessor do
  @moduledoc """
  Downloads a staged inAction clip with yt-dlp and stores it as MP4.
  """

  alias FosBjj.Workers.ProcessInActionVideo.Storage

  @mp4_720p_video_only_format "bestvideo[height<=720][ext=mp4]/bestvideo[height<=720]"

  def process(staging) do
    output_dir = output_dir()
    File.mkdir_p!(output_dir)

    output_path = Path.join(output_dir, output_filename(staging))

    opts = [
      {"format", @mp4_720p_video_only_format},
      {"download-sections", download_section(staging)},
      {"merge-output-format", "mp4"},
      {"output", output_path},
      "force-overwrites",
      "no-playlist"
    ]

    case Caller.download(staging.source_url, opts) do
      {:ok, _filename} ->
        filename = Path.basename(output_path)
        storage_key = storage_key(filename)

        case Storage.store(output_path, storage_key, content_type: "video/mp4") do
          {:ok, _public_url, _storage_key} = result ->
            maybe_cleanup(output_path)
            result

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def download_section(staging) do
    "*#{format_timestamp(staging.start_seconds)}-#{format_timestamp(staging.end_seconds)}"
  end

  def output_filename(staging), do: "in-action-#{staging.id}.mp4"

  defp output_dir do
    Application.get_env(:fos_bjj, :in_action_video_tmp_dir) ||
      Application.get_env(
        :fos_bjj,
        :in_action_video_output_dir,
        Path.expand("../../../../priv/static/videos/in-action", __DIR__)
      )
  end

  defp storage_key(filename), do: join_url_path("in-action", filename)

  defp maybe_cleanup(path) do
    if Storage.cleanup_after_store?() do
      File.rm(path)
    else
      :ok
    end
  end

  defp join_url_path(left, right) do
    left = String.trim_trailing(left, "/")
    right = String.trim_leading(right, "/")

    "#{left}/#{right}"
  end

  defp format_timestamp(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    minutes = seconds |> rem(3600) |> div(60)
    seconds = rem(seconds, 60)

    [hours, minutes, seconds]
    |> Enum.map(&String.pad_leading(to_string(&1), 2, "0"))
    |> Enum.join(":")
  end
end
