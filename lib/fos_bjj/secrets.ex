defmodule FosBjj.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :strategies, :google, :client_id],
        FosBjj.Accounts.User,
        _opts,
        _context
      ) do
    fetch_string_env(:google_client_id)
  end

  def secret_for(
        [:authentication, :strategies, :google, :client_secret],
        FosBjj.Accounts.User,
        _opts,
        _context
      ) do
    fetch_string_env(:google_client_secret)
  end

  def secret_for(
        [:authentication, :strategies, :google, :redirect_uri],
        FosBjj.Accounts.User,
        _opts,
        _context
      ) do
    fetch_string_env(:google_redirect_uri)
  end

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        FosBjj.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:fos_bjj, :token_signing_secret)
  end

  defp fetch_string_env(key) do
    case Application.fetch_env(:fos_bjj, key) do
      {:ok, value} when is_binary(value) and byte_size(value) > 0 -> {:ok, value}
      _ -> :error
    end
  end
end
