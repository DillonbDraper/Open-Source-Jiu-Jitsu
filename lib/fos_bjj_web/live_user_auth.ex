defmodule FosBjjWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use FosBjjWeb, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {FosBjjWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    {:cont, socket}
  end

  def on_mount(:live_user_required, _params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    user = socket.assigns[:current_user]

    cond do
      user && FosBjj.Accounts.User.verified?(user) ->
        {:cont, socket}

      user ->
        # User exists but not verified - redirect to verification notice
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in?unverified=true")}

      true ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_admin_required, _params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    user = socket.assigns[:current_user]

    cond do
      user && FosBjj.Accounts.User.verified?(user) && FosBjj.Accounts.User.admin?(user) ->
        {:cont, socket}

      user && !FosBjj.Accounts.User.verified?(user) ->
        # User exists but not verified
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in?unverified=true")}

      user ->
        # User is verified but not admin
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}

      true ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && FosBjj.Accounts.User.verified?(user) do
      # Only redirect verified users away from sign-in pages
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      # Allow unverified users to stay on sign-in pages (to see verification messages)
      {:cont, assign(socket, :current_user, user)}
    end
  end
end
