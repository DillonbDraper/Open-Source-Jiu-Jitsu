defmodule FosBjjWeb.Plugs.RequireAdmin do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller
  use FosBjjWeb, :verified_routes

  alias FosBjj.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        cond do
          User.admin?(user) ->
            conn

          User.verified?(user) ->
            conn
            |> redirect(to: ~p"/")
            |> halt()

          true ->
            conn
            |> redirect(to: ~p"/sign-in?unverified=true")
            |> halt()
        end

      _ ->
        conn
        |> redirect(to: ~p"/sign-in")
        |> halt()
    end
  end
end
