defmodule FosBjjWeb.Live.Auth.SignInLiveTest do
  use FosBjjWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders Google sign-in button", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    assert has_element?(view, "#google-sign-in")
    assert has_element?(view, "#google-sign-in a", "Sign in with Google")
  end
end
