defmodule FosBjjWeb.Components.InboxComponent do
  @moduledoc """
  LiveComponent for the user inbox with message notifications.
  Shows an inbox icon with unread count badge and a modal to view/manage messages.
  """
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.UserMessage
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_message, nil)
     |> assign(:messages, [])
     |> assign(:unread_count, 0)}
  end

  @impl true
  def update(%{current_user: user} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if user do
        unread_count = get_unread_count(user)
        messages = get_inbox_messages(user)

        socket
        |> assign(:unread_count, unread_count)
        |> assign(:messages, messages)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("open_inbox", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("close_inbox", _, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_message, nil)}
  end

  @impl true
  def handle_event("select_message", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user

    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))

    socket =
      if message && !message.received do
        UserMessage
        |> Ash.get!(message_id, actor: user)
        |> Ash.Changeset.for_update(:mark_as_read, %{}, actor: user)
        |> Ash.update!()

        messages = get_inbox_messages(user)
        unread_count = get_unread_count(user)

        socket
        |> assign(:messages, messages)
        |> assign(:unread_count, unread_count)
      else
        socket
      end

    selected = Enum.find(socket.assigns.messages, &(&1.id == message_id))
    {:noreply, assign(socket, :selected_message, selected)}
  end

  @impl true
  def handle_event("mark_as_read", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user

    UserMessage
    |> Ash.get!(message_id, actor: user)
    |> Ash.Changeset.for_update(:mark_as_read, %{}, actor: user)
    |> Ash.update!()

    messages = get_inbox_messages(user)
    unread_count = get_unread_count(user)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_event("back_to_list", _, socket) do
    {:noreply, assign(socket, :selected_message, nil)}
  end

  defp get_unread_count(user) do
    UserMessage
    |> Ash.Query.for_read(:unread_count, %{user_id: user.id})
    |> Ash.read!(actor: user)
    |> length()
  end

  defp get_inbox_messages(user) do
    UserMessage
    |> Ash.Query.for_read(:inbox_messages, %{user_id: user.id})
    |> Ash.Query.load([:sender, :shared_video])
    |> Ash.read!(actor: user)
  end

  defp sender_name(message) do
    case message.sender do
      nil -> "System Message"
      sender -> sender.user_name || sender.email
    end
  end

  defp message_body_present?(message) do
    case message.body do
      body when is_binary(body) -> String.trim(body) != ""
      _ -> false
    end
  end

  defp shared_video_message?(message) do
    case message.shared_video do
      %Ash.NotLoaded{} -> UserMessage.type_value(message.type) == :video_shared_by_coach
      nil -> UserMessage.type_value(message.type) == :video_shared_by_coach
      _ -> true
    end
  end

  defp shared_video_title(message) do
    case message.shared_video do
      %{title: title} when is_binary(title) and title != "" -> title
      _ -> "Shared video"
    end
  end

  defp message_preview(message) do
    cond do
      shared_video_message?(message) && message_body_present?(message) ->
        "#{shared_video_title(message)} - #{message.body}"

      shared_video_message?(message) ->
        shared_video_title(message)

      message_body_present?(message) ->
        message.body

      true ->
        "System notification"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <div class="relative inline-flex items-center justify-center">
        <.button
          id={"#{@id}-open"}
          type="button"
          phx-click="open_inbox"
          phx-target={@myself}
          variant="transparent"
          color="natural"
          size="small"
          class="text-white hover:text-white/80"
        >
          <.icon name="hero-envelope" class="w-8 h-8" />
        </.button>

        <%= if @unread_count > 0 do %>
          <.badge
            id={"#{@id}-unread-badge"}
            badge_position="top-0 left-1/2 -translate-x-1/2 -translate-y-1.5 z-10"
            variant="default"
            color="danger"
            size="extra_small"
            rounded="full"
            circle
            class="font-bold"
          >
            {@unread_count}
          </.badge>
        <% end %>
      </div>

      <.modal
        :if={@show_modal}
        show
        id={"#{@id}-modal"}
        size="large"
        on_cancel={JS.push("close_inbox", target: @myself)}
        title={
          if @selected_message, do: "Message from #{sender_name(@selected_message)}", else: "Inbox"
        }
        title_class="text-lg text-gray-900 dark:text-gray-100"
        inner_wrapper_class="p-4"
        focus_wrap_class="max-h-[80vh] overflow-hidden"
        content_class="flex max-h-[60vh] flex-col gap-4"
      >
        <div class="flex-1 overflow-y-auto pr-1">
          <%= if @selected_message do %>
            <div class="space-y-1">
              <.button
                id={"#{@id}-back"}
                type="button"
                phx-click="back_to_list"
                phx-target={@myself}
                variant="transparent"
                color="primary"
                size="small"
                class="gap-1"
              >
                <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to messages
              </.button>

              <.small class="text-gray-600 dark:text-gray-300">
                {Calendar.strftime(@selected_message.inserted_at, "%b %d, %Y at %I:%M %p")}
              </.small>

              <%= if shared_video_message?(@selected_message) do %>
                <.p class="text-sm font-semibold text-gray-900 dark:text-gray-100">
                  Video: {shared_video_title(@selected_message)}
                </.p>
                <%= if message_body_present?(@selected_message) do %>
                  <.hr class="my-2 border-gray-200 dark:border-gray-700" />
                <% end %>
              <% end %>

              <%= if message_body_present?(@selected_message) do %>
                <.p class="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">
                  {@selected_message.body}
                </.p>
              <% end %>
            </div>
          <% else %>
            <%= if @messages == [] do %>
              <div class="text-center py-8 text-gray-500">
                <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                <.p class="text-gray-500">No messages yet</.p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for message <- @messages do %>
                  <div class={[
                    "p-3 rounded-lg border transition-colors",
                    if(message.received,
                      do:
                        "bg-gray-50 dark:bg-gray-800/50 opacity-80 border-gray-200 dark:border-gray-700",
                      else:
                        "bg-white dark:bg-gray-800 border-blue-200 dark:border-blue-700 hover:bg-blue-50 dark:hover:bg-blue-900/20"
                    )
                  ]}>
                    <div class="flex items-start justify-between gap-2">
                      <div
                        id={"#{@id}-message-#{message.id}"}
                        class="flex-1 min-w-0 cursor-pointer"
                        phx-click="select_message"
                        phx-value-id={message.id}
                        phx-target={@myself}
                      >
                        <div class="flex items-center gap-2 mb-1">
                          <.p class={"text-sm text-gray-900 dark:text-gray-100 #{if(message.received, do: "font-normal", else: "font-semibold")}"}>
                            {sender_name(message)}
                          </.p>
                          <.small class="text-xs text-gray-500">
                            {Calendar.strftime(message.inserted_at, "%b %d, %Y %I:%M %p")}
                          </.small>
                        </div>
                        <.p class={"text-sm truncate #{if(message.received, do: "text-gray-600 dark:text-gray-300", else: "text-gray-800 dark:text-gray-200")}"}>
                          {message_preview(message)}
                        </.p>
                      </div>
                      <%= unless message.received do %>
                        <.tooltip
                          id={"mark-read-tooltip-#{message.id}"}
                          position="left"
                          color="dark"
                        >
                          <:trigger>
                            <.button
                              id={"#{@id}-mark-read-#{message.id}"}
                              type="button"
                              phx-click="mark_as_read"
                              phx-value-id={message.id}
                              phx-target={@myself}
                              variant="transparent"
                              color="success"
                              size="extra_small"
                              class="p-1"
                            >
                              <.icon name="hero-check-badge" class="w-8 h-8" />
                            </.button>
                          </:trigger>
                          <:content>Mark as read</:content>
                        </.tooltip>
                      <% end %>
                      <%= if message.received do %>
                        <div
                          id={"#{@id}-mark-read-#{message.id}-done"}
                          class="text-green-500 p-1"
                        >
                          <.icon name="hero-check-badge" class="w-8 h-8" />
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>

        <div class="border-t border-gray-200 dark:border-gray-700 pt-4 text-center">
          <.button_link
            id={"#{@id}-view-all"}
            navigate="/profile"
            variant="transparent"
            color="primary"
            size="small"
            phx-click="close_inbox"
            phx-target={@myself}
          >
            View all messages in profile
          </.button_link>
        </div>
      </.modal>
    </div>
    """
  end
end
