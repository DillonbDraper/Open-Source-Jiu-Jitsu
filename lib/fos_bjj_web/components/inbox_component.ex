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
    |> Ash.Query.load(:sender)
    |> Ash.read!(actor: user)
  end

  defp sender_name(message) do
    case message.sender do
      nil -> "System Message"
      sender -> sender.user_name || sender.email
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <button
        type="button"
        phx-click="open_inbox"
        phx-target={@myself}
        class="text-white hover:text-white/80 cursor-pointer transition-colors relative"
      >
        <.icon name="hero-envelope" class="w-8 h-8" />
        <%= if @unread_count > 0 do %>
          <span class="absolute -top-3 bg-red-500 text-white text-sm font-bold rounded-full min-w-6 h-6 flex items-center justify-center px-1.5">
            {@unread_count}
          </span>
        <% end %>
      </button>

      <%= if @show_modal do %>
        <div
          id={"#{@id}-modal"}
          class="fixed inset-0 z-50"
          phx-window-keydown="close_inbox"
          phx-key="escape"
          phx-target={@myself}
        >
          <div class="fixed inset-0 bg-zinc-50/90 dark:bg-zinc-600/90" aria-hidden="true"></div>
          <div class="fixed inset-0 overflow-y-auto">
            <div class="flex min-h-full items-center justify-center p-4">
              <div class="relative bg-white dark:bg-base-bg-dark rounded-lg shadow-xl max-w-lg w-full max-h-[80vh] overflow-hidden">
                <div class="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
                  <h3 class="text-lg font-semibold">
                    <%= if @selected_message do %>
                      Message from {sender_name(@selected_message)}
                    <% else %>
                      Inbox
                    <% end %>
                  </h3>
                  <button
                    type="button"
                    phx-click="close_inbox"
                    phx-target={@myself}
                    class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                  >
                    <.icon name="hero-x-mark" class="w-6 h-6" />
                  </button>
                </div>

                <div class="p-4 overflow-y-auto max-h-[60vh]">
                  <%= if @selected_message do %>
                    <div>
                      <button
                        type="button"
                        phx-click="back_to_list"
                        phx-target={@myself}
                        class="flex items-center gap-1 text-sm text-blue-600 hover:text-blue-800 mb-4"
                      >
                        <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to messages
                      </button>
                      <div class="text-sm text-gray-600 dark:text-gray-300 mb-2">
                        {Calendar.strftime(@selected_message.inserted_at, "%b %d, %Y at %I:%M %p")}
                      </div>
                      <div class="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">
                        {@selected_message.body}
                      </div>
                    </div>
                  <% else %>
                    <%= if @messages == [] do %>
                      <div class="text-center py-8 text-gray-500">
                        <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                        <p>No messages yet</p>
                      </div>
                    <% else %>
                      <div class="space-y-2">
                        <%= for message <- @messages do %>
                          <div class={[
                            "p-3 rounded-lg border cursor-pointer transition-colors",
                            if(message.received,
                              do:
                                "bg-gray-50 dark:bg-gray-800/50 opacity-80 border-gray-200 dark:border-gray-700",
                              else:
                                "bg-white dark:bg-gray-800 border-blue-200 dark:border-blue-700 hover:bg-blue-50 dark:hover:bg-blue-900/20"
                            )
                          ]}>
                            <div class="flex items-start justify-between gap-2">
                              <div
                                class="flex-1 min-w-0"
                                phx-click="select_message"
                                phx-value-id={message.id}
                                phx-target={@myself}
                              >
                                <div class="flex items-center gap-2 mb-1">
                                  <span class={[
                                    "text-sm",
                                    "text-gray-900 dark:text-gray-100",
                                    if(message.received, do: "font-normal", else: "font-semibold")
                                  ]}>
                                    {sender_name(message)}
                                  </span>
                                  <span class="text-xs text-gray-500">
                                    {Calendar.strftime(message.inserted_at, "%b %d, %Y %I:%M %p")}
                                  </span>
                                </div>
                                <p class={[
                                  "text-sm truncate",
                                  if(message.received,
                                    do: "text-gray-600 dark:text-gray-300",
                                    else: "text-gray-800 dark:text-gray-200"
                                  )
                                ]}>
                                  {message.body}
                                </p>
                              </div>
                              <%= unless message.received do %>
                                <.tooltip
                                  id={"mark-read-tooltip-#{message.id}"}
                                  position="left"
                                  color="dark"
                                >
                                  <:trigger>
                                    <button
                                      type="button"
                                      phx-click="mark_as_read"
                                      phx-value-id={message.id}
                                      phx-target={@myself}
                                      class="text-gray-400 hover:text-green-600 transition-colors p-1"
                                    >
                                      <.icon name="hero-check-badge" class="w-8 h-8" />
                                    </button>
                                  </:trigger>
                                  <:content>Mark as read</:content>
                                </.tooltip>
                              <% end %>
                              <%= if message.received do %>
                                <span class="text-green-500 p-1">
                                  <.icon name="hero-check-badge" class="w-8 h-8" />
                                </span>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  <% end %>
                </div>

                <div class="p-4 border-t border-gray-200 dark:border-gray-700 text-center">
                  <.link
                    navigate="/profile"
                    class="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400"
                    phx-click="close_inbox"
                    phx-target={@myself}
                  >
                    View all messages in profile
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
