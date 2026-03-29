defmodule FosBjjWeb.MessagesLiveTest do
  use FosBjjWeb.ConnCase, async: true

  import FosBjj.Fixtures
  import Phoenix.LiveViewTest

  alias AshAuthentication.Plug.Helpers

  test "verified users can access message center", %{conn: conn} do
    {user, _token} = user_with_token_fixture(%{confirmed: true})

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    assert {:ok, view, _html} = live(conn, ~p"/messages")
    assert has_element?(view, "#message-center-tabs")
    assert has_element?(view, "#received-messages-table")
    assert has_element?(view, "#message-center-back-link[href='/database']")
  end

  test "unverified users are redirected from message center", %{conn: conn} do
    {user, _token} = user_with_token_fixture()

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/messages")
    assert to == "/sign-in?unverified=true"
  end

  test "students do not see sent messages table", %{conn: conn} do
    {user, _token} = user_with_token_fixture(%{confirmed: true, role: "student"})

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    assert {:ok, view, _html} = live(conn, ~p"/messages")
    assert has_element?(view, "#received-messages-table")
    refute has_element?(view, "#sent-messages-table")
  end

  test "coaches see sent messages table", %{conn: conn} do
    {user, _token} = user_with_token_fixture(%{confirmed: true, role: "coach"})

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(user)

    assert {:ok, view, _html} = live(conn, ~p"/messages")
    assert has_element?(view, "#received-messages-table")
    assert has_element?(view, "#sent-messages-table")
  end

  test "received messages show a video icon in action column when linked", %{conn: conn} do
    {recipient, _token} = user_with_token_fixture(%{confirmed: true})
    sender = user_fixture(%{confirmed: true, role: "coach"})
    video = video_fixture(%{user: sender})

    message =
      message_fixture(%{
        type: :video_shared_by_coach,
        recipient: recipient,
        sender: sender,
        video: video
      })

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(recipient)

    assert {:ok, view, _html} = live(conn, ~p"/messages")

    assert has_element?(
             view,
             "#message-video-link-#{message.id}[href='/videos/#{video.id}']"
           )

    refute render(view) =~ "Watch:"
  end

  test "sent messages show a far-right video icon column when linked", %{conn: conn} do
    {sender, _token} = user_with_token_fixture(%{confirmed: true, role: "coach"})
    recipient = user_fixture(%{confirmed: true})
    video = video_fixture(%{user: sender})

    message =
      message_fixture(%{
        type: :video_shared_by_coach,
        recipient: recipient,
        sender: sender,
        video: video
      })

    conn =
      conn
      |> init_test_session(%{})
      |> Helpers.store_in_session(sender)

    assert {:ok, view, _html} = live(conn, ~p"/messages")

    assert has_element?(
             view,
             "#sent-message-video-link-#{message.message_group_id}[href='/videos/#{video.id}']"
           )

    refute render(view) =~ "Watch:"
  end
end
