defmodule FosBjj.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        FosBjj.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:fos_bjj, :token_signing_secret)
  end
end
