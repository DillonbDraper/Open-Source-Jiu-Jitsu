defmodule FosBjjWeb.AuthControllerTest do
  use FosBjjWeb.ConnCase, async: true

  import FosBjj.Fixtures

  alias FosBjjWeb.AuthController

  test "success sets confirmation message and redirects", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> init_test_session(%{})
      |> fetch_flash()
      |> AuthController.success({:confirm_new_user, :confirm}, user, "token")

    assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
             "Your email address has now been confirmed"

    assert redirected_to(conn) == "/database"
  end

  test "success sets reset message and honors return_to", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> init_test_session(%{})
      |> fetch_flash()
      |> put_session(:return_to, "/special")
      |> AuthController.success({:password, :reset}, user, "token")

    assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
             "Your password has successfully been reset"

    assert redirected_to(conn) == "/special"
    assert get_session(conn, :return_to) == nil
  end

  test "failure shows unconfirmed message", %{conn: conn} do
    reason = %AshAuthentication.Errors.AuthenticationFailed{
      caused_by: %Ash.Error.Forbidden{
        errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
      }
    }

    conn =
      conn
      |> init_test_session(%{})
      |> fetch_flash()
      |> AuthController.failure(:password, reason)

    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "have not confirmed your account"
    assert redirected_to(conn) == "/sign-in"
  end

  test "sign_out clears session and redirects", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> fetch_flash()
      |> put_session(:return_to, "/bye")
      |> put_session(:extra, "value")
      |> AuthController.sign_out(%{})

    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "You are now signed out"
    assert redirected_to(conn) == "/bye"
    assert get_session(conn, :extra) == nil
  end
end
