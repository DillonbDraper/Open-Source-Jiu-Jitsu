defmodule FosBjjWeb.LiveUserAuthTest do
  use FosBjjWeb.ConnCase, async: true

  alias FosBjj.Accounts.User
  alias FosBjjWeb.LiveUserAuth

  test "live_user_required allows verified users" do
    user = struct(User, confirmed_at: DateTime.utc_now())

    {:cont, socket} =
      LiveUserAuth.on_mount(:live_user_required, %{}, %{}, build_socket(%{current_user: user}))

    assert socket.redirected == nil
  end

  test "live_user_required redirects unverified users" do
    user = struct(User, confirmed_at: nil)

    {:halt, socket} =
      LiveUserAuth.on_mount(:live_user_required, %{}, %{}, build_socket(%{current_user: user}))

    assert {:redirect, %{to: "/sign-in?unverified=true"}} = socket.redirected
  end

  test "live_user_required redirects when no user" do
    {:halt, socket} = LiveUserAuth.on_mount(:live_user_required, %{}, %{}, build_socket(%{}))

    assert {:redirect, %{to: "/sign-in"}} = socket.redirected
  end

  test "live_admin_required allows verified admins" do
    user = struct(User, confirmed_at: DateTime.utc_now(), role_name: "admin")

    {:cont, socket} =
      LiveUserAuth.on_mount(:live_admin_required, %{}, %{}, build_socket(%{current_user: user}))

    assert socket.redirected == nil
  end

  test "live_admin_required redirects verified non-admins" do
    user = struct(User, confirmed_at: DateTime.utc_now(), role_name: "student")

    {:halt, socket} =
      LiveUserAuth.on_mount(:live_admin_required, %{}, %{}, build_socket(%{current_user: user}))

    assert {:redirect, %{to: "/"}} = socket.redirected
  end

  test "live_admin_required redirects unverified users" do
    user = struct(User, confirmed_at: nil, role_name: "admin")

    {:halt, socket} =
      LiveUserAuth.on_mount(:live_admin_required, %{}, %{}, build_socket(%{current_user: user}))

    assert {:redirect, %{to: "/sign-in?unverified=true"}} = socket.redirected
  end

  test "live_admin_required redirects when no user" do
    {:halt, socket} = LiveUserAuth.on_mount(:live_admin_required, %{}, %{}, build_socket(%{}))

    assert {:redirect, %{to: "/sign-in"}} = socket.redirected
  end

  test "live_no_user redirects verified users" do
    user = struct(User, confirmed_at: DateTime.utc_now())

    {:halt, socket} =
      LiveUserAuth.on_mount(:live_no_user, %{}, %{}, build_socket(%{current_user: user}))

    assert {:redirect, %{to: "/"}} = socket.redirected
  end

  test "live_no_user allows unverified users" do
    user = struct(User, confirmed_at: nil)

    {:cont, socket} =
      LiveUserAuth.on_mount(:live_no_user, %{}, %{}, build_socket(%{current_user: user}))

    assert socket.redirected == nil
  end

  defp build_socket(assigns) do
    %Phoenix.LiveView.Socket{
      endpoint: FosBjjWeb.Endpoint,
      router: FosBjjWeb.Router,
      assigns: Map.merge(%{__changed__: %{}}, assigns)
    }
  end
end
