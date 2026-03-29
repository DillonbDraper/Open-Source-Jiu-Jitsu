defmodule FosBjjWeb.UserProfileLiveTest do
  use FosBjjWeb.ConnCase, async: true

  import FosBjj.Fixtures
  import Phoenix.LiveViewTest

  alias FosBjj.Accounts.User
  alias AshAuthentication.Plug.Helpers

  test "verified users can access profile", %{conn: conn} do
    {user, _token} = user_with_token_fixture(%{confirmed: true})

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    assert {:ok, view, _html} = live(conn, ~p"/profile")
    refute has_element?(view, "#profile-messages-tabs")
  end

  test "unverified users are redirected from profile", %{conn: conn} do
    {user, _token} = user_with_token_fixture()

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/profile")
    assert to == "/sign-in?unverified=true"
  end

  test "verified users can update username from profile modal", %{conn: conn} do
    old_user_name = "old_name_#{unique_integer()}"
    new_user_name = "new_name_#{unique_integer()}"
    {user, _token} = user_with_token_fixture(%{confirmed: true, user_name: old_user_name})

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    {:ok, view, _html} = live(conn, ~p"/profile")

    view
    |> element("#edit-profile")
    |> render_click()

    view
    |> form("#user-profile-form", %{"profile" => %{"user_name" => new_user_name}})
    |> render_submit()

    refute has_element?(view, "#profile-modal")

    updated_user = Ash.get!(User, user.id, authorize?: false)
    assert updated_user.user_name == new_user_name
  end

  test "profile username save shows helpful error when username is taken", %{conn: conn} do
    taken_name = "taken_name_#{unique_integer()}"
    _another_existing = user_fixture(%{confirmed: true, user_name: taken_name})

    {user, _token} =
      user_with_token_fixture(%{confirmed: true, user_name: "owner_#{unique_integer()}"})

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    {:ok, view, _html} = live(conn, ~p"/profile")

    view
    |> element("#edit-profile")
    |> render_click()

    view
    |> form("#user-profile-form", %{"profile" => %{"user_name" => taken_name}})
    |> render_submit()

    assert has_element?(view, "#profile-modal")

    assert has_element?(
             view,
             "#user-profile-form",
             "That username is already taken. Please choose another one."
           )

    unchanged_user = Ash.get!(User, user.id, authorize?: false)
    assert unchanged_user.user_name != taken_name
  end
end
