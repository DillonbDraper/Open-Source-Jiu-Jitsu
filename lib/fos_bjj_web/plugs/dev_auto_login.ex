defmodule FosBjjWeb.Plugs.DevAutoLogin do
  @moduledoc """
  A plug that automatically logs in a dev user when in development mode.

  This plug should only be used in development. It will:
  1. Check if auto-login is enabled via config
  2. Check if a user is already logged in
  3. If not, get or create a dev user and log them in

  ## Configuration

  Enable in config/dev.exs:

      config :fos_bjj, :dev_auto_login, true

  The dev user will be created with:
  - Email: dev@localhost
  - Password: devpassword123
  """
  @behaviour Plug

  require Logger
  require Ash.Query

  @dev_email "dev@localhost"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if auto_login_enabled?() and not user_logged_in?(conn) do
      case get_or_create_dev_user() do
        {:ok, user} ->
          # Generate JWT token for the user
          case AshAuthentication.Jwt.token_for_user(user) do
            {:ok, token, _claims} ->
              # Store token and user info in session manually
              conn
              |> Plug.Conn.put_session(:user_token, token)
              |> Plug.Conn.assign(:current_user, user)

            {:error, token_error} ->
              Logger.warning("DevAutoLogin: Failed to generate token: #{inspect(token_error)}")
              conn
          end

        {:error, reason} ->
          Logger.warning("DevAutoLogin: Failed to get/create dev user: #{inspect(reason)}")
          conn
      end
    else
      conn
    end
  end

  defp auto_login_enabled? do
    Application.get_env(:fos_bjj, :dev_auto_login, false)
  end

  defp user_logged_in?(conn) do
    conn.assigns[:current_user] != nil
  end

  defp get_or_create_dev_user do
    case FosBjj.Accounts.User
         |> Ash.Query.filter(email == ^@dev_email)
         |> Ash.Query.load(:role)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} ->
        create_dev_user()

      {:ok, user} ->
        {:ok, user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_dev_user do
    case FosBjj.Accounts.User
         |> Ash.Changeset.for_create(
           :register_with_password,
           %{
             email: @dev_email,
             password: "devpassword123",
             password_confirmation: "devpassword123"
           },
           authorize?: false
         )
         |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())
         |> Ash.Changeset.force_change_attribute(:role_name, "admin")
         |> Ash.create(authorize?: false) do
      {:ok, user} ->
        # Reload with role to ensure consistent data structure
        {:ok, reloaded_user} =
          FosBjj.Accounts.User
          |> Ash.Query.filter(id == ^user.id)
          |> Ash.Query.load(:role)
          |> Ash.read_one(authorize?: false)

        {:ok, reloaded_user}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
