defmodule FosBjj.Accounts.UserMessageTest do
  use FosBjj.DataCase, async: true

  import FosBjj.Fixtures

  alias FosBjj.Accounts.UserMessage

  test "send creates a shared video message" do
    recipient = user_fixture()
    sender = user_fixture(%{role: "coach"})
    video = video_fixture(%{user: sender})

    message =
      Ash.create!(
        UserMessage,
        %{
          body: "Check this out",
          recipient_id: recipient.id,
          shared_video_id: video.id
        },
        action: :send,
        actor: sender
      )

    assert message.type == :video_shared_by_coach
    assert message.sender_id == sender.id
    assert message.recipient_id == recipient.id
    assert message.shared_video_id == video.id
    assert is_binary(message.message_group_id)
  end

  test "send_system_message creates a system notification" do
    recipient = user_fixture()

    message =
      Ash.create!(
        UserMessage,
        %{
          body: "System update",
          recipient_id: recipient.id
        },
        action: :send_system_message
      )

    assert message.type == :system_notification
    assert message.sender_id == nil
    assert is_binary(message.message_group_id)
  end

  test "mark_as_read updates received flag" do
    recipient = user_fixture()
    message = message_fixture(%{type: :system_notification, recipient: recipient})

    updated = Ash.update!(message, %{}, action: :mark_as_read, actor: recipient)

    assert updated.received
  end

  test "list_for_user returns only recipient messages" do
    recipient = user_fixture()
    other_user = user_fixture()

    _message = message_fixture(%{recipient: recipient})
    _other_message = message_fixture(%{recipient: other_user})

    page =
      UserMessage
      |> Ash.Query.for_read(:list_for_user, %{user_id: recipient.id})
      |> Ash.read!(actor: recipient, page: [limit: 10, offset: 0, count: true])

    assert page.count == 1
    assert Enum.all?(page.results, &(&1.recipient_id == recipient.id))
  end

  test "unread_count excludes received messages" do
    recipient = user_fixture()
    unread = message_fixture(%{type: :system_notification, recipient: recipient})

    _read =
      message_fixture(%{type: :system_notification, recipient: recipient})
      |> Ash.update!(%{}, action: :mark_as_read, actor: recipient)

    unread_results =
      UserMessage
      |> Ash.Query.for_read(:unread_count, %{user_id: recipient.id})
      |> Ash.read!(actor: recipient)

    assert Enum.any?(unread_results, &(&1.id == unread.id))
    assert Enum.all?(unread_results, &(&1.received == false))
  end

  test "inbox_messages limits results" do
    recipient = user_fixture()

    Enum.each(1..6, fn _ ->
      message_fixture(%{type: :system_notification, recipient: recipient})
    end)

    messages =
      UserMessage
      |> Ash.Query.for_read(:inbox_messages, %{user_id: recipient.id})
      |> Ash.read!(actor: recipient)

    assert length(messages) == 5
  end
end
