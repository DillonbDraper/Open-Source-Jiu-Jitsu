defmodule FosBjjWeb.InboxLiveTest do
  use FosBjjWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FosBjj.Fixtures

  alias FosBjjWeb.InboxLive

  test "open_inbox shows modal and unread badge", %{conn: conn} do
    recipient = user_fixture()
    message = message_fixture(%{type: :video_shared_by_coach, recipient: recipient})

    {:ok, view, _html} =
      live_isolated(conn, InboxLive, session: %{"current_user" => recipient})

    assert has_element?(view, "#inbox-unread-badge")

    view
    |> element("#inbox-open-button")
    |> render_click()

    assert has_element?(view, "#inbox-modal")
    assert has_element?(view, "#inbox-message-#{message.id}")
  end

  test "select_message marks as read and navigates to shared video", %{conn: conn} do
    recipient = user_fixture()
    sender = user_fixture(%{role: "coach"})
    video = video_fixture(%{user: sender})

    message =
      message_fixture(%{
        type: :video_shared_by_coach,
        recipient: recipient,
        sender: sender,
        video: video
      })

    {:ok, view, _html} =
      live_isolated(conn, InboxLive, session: %{"current_user" => recipient})

    view
    |> element("#inbox-open-button")
    |> render_click()

    view
    |> element("#inbox-message-#{message.id}")
    |> render_click()

    refute has_element?(view, "#inbox-unread-badge")
    assert has_element?(view, "#inbox-shared-video-#{video.id}")

    view
    |> element("#inbox-shared-video-#{video.id}")
    |> render_click()

    assert_redirect(view, "/videos/#{video.id}")
  end

  test "mark_as_read updates list and system preview", %{conn: conn} do
    recipient = user_fixture()

    system_message =
      message_fixture(%{type: :system_notification, recipient: recipient, body: nil})

    {:ok, view, _html} =
      live_isolated(conn, InboxLive, session: %{"current_user" => recipient})

    view
    |> element("#inbox-open-button")
    |> render_click()

    assert has_element?(view, "#inbox-message-#{system_message.id}", "System notification")

    view
    |> element("#mark-read-#{system_message.id}")
    |> render_click()

    assert has_element?(view, "#mark-read-#{system_message.id}-done")
  end
end
