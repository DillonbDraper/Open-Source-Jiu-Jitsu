defmodule FosBjjWeb.Components.MessagesTableComponent do
  @moduledoc """
  LiveComponent for displaying a paginated, searchable table of user messages.
  """
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.UserMessage
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, nil)
     |> assign(:messages_page, 1)
     |> assign(:messages_search_query, "")}
  end

  @impl true
  def update(%{current_user: user} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns.messages == nil do
        messages = list_user_messages(user, "", 1)
        assign(socket, :messages, messages)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search_messages", %{"query" => query}, socket) do
    page = 1
    messages = list_user_messages(socket.assigns.current_user, query, page)

    {:noreply,
     socket
     |> assign(:messages_search_query, query)
     |> assign(:messages, messages)
     |> assign(:messages_page, page)}
  end

  @impl true
  def handle_event("messages_pagination", params, socket) do
    current_page = socket.assigns.messages_page || 1
    total_pages = ceil(socket.assigns.messages.count / 10)

    page =
      case params["action"] do
        "select" -> params["page"]
        "next" -> min(current_page + 1, total_pages)
        "previous" -> max(current_page - 1, 1)
        "first" -> 1
        "last" -> total_pages
        _ -> params["page"] || current_page
      end

    messages =
      list_user_messages(socket.assigns.current_user, socket.assigns.messages_search_query, page)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:messages_page, page)}
  end

  @impl true
  def handle_event("mark_message_read", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user

    UserMessage
    |> Ash.get!(message_id, actor: user)
    |> Ash.Changeset.for_update(:mark_as_read, %{}, actor: user)
    |> Ash.update!()

    messages =
      list_user_messages(user, socket.assigns.messages_search_query, socket.assigns.messages_page)

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user

    UserMessage
    |> Ash.get!(message_id, actor: user)
    |> Ash.destroy!(actor: user)

    page = socket.assigns.messages_page
    query = socket.assigns.messages_search_query

    messages = list_user_messages(user, query, page)

    {messages, page} =
      if messages.results == [] && page > 1 do
        new_page = 1
        {list_user_messages(user, query, new_page), new_page}
      else
        {messages, page}
      end

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:messages_page, page)
     |> put_flash(:info, "Message deleted")}
  end

  defp list_user_messages(user, query, page) do
    offset = (page - 1) * 10

    UserMessage
    |> Ash.Query.filter(recipient_id == ^user.id)
    |> Ash.Query.load([:sender, :shared_video])
    |> then(fn q ->
      if query != "" do
        query_string = "%#{query}%"

        Ash.Query.filter(
          q,
          ilike(body, ^query_string) or
            (not is_nil(sender_id) and ilike(sender.user_name, ^query_string)) or
            (not is_nil(sender_id) and ilike(sender.email, ^query_string))
        )
      else
        q
      end
    end)
    |> Ash.Query.sort(received: :asc, inserted_at: :desc)
    |> Ash.read!(actor: user, page: [limit: 10, offset: offset, count: true])
  end

  defp message_sender_name(message) do
    case message.sender do
      nil -> "System"
      sender -> sender.user_name || sender.email
    end
  end

  defp message_type_label(message) do
    UserMessage.type_label(message.type)
  end

  defp shared_video_message?(message) do
    UserMessage.type_value(message.type) == :video_shared_by_coach
  end

  defp message_body_present?(message) do
    case message.body do
      body when is_binary(body) -> String.trim(body) != ""
      _ -> false
    end
  end

  defp shared_video_summary(message) do
    "Video shared by #{message_sender_name(message)}"
  end

  defp message_preview(message) do
    cond do
      message_body_present?(message) -> message.body
      shared_video_message?(message) -> shared_video_summary(message)
      true -> "System notification"
    end
  end

  defp message_trigger_class(message) do
    [
      "truncate max-w-xs cursor-help block",
      message.received && "text-base-content/80",
      !message.received && "font-semibold"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
      <.h3 class="text-lg font-medium mb-4">My Messages</.h3>
      <%= if @messages.results == [] do %>
        <div
          id="messages-empty-state"
          class="rounded-xl border border-dashed border-base-200 bg-base-50 px-4 py-10 text-center"
        >
          <.p class="text-sm text-base-content/70">You have no messages.</.p>
        </div>
      <% else %>
        <div class="mb-4">
          <form phx-change="search_messages" phx-submit="search_messages" phx-target={@myself}>
            <.search_field
              name="query"
              value={@messages_search_query}
              placeholder="Search messages by content or sender..."
              phx-change="search_messages"
              phx-target={@myself}
              phx-debounce="400"
            />
          </form>
        </div>

        <.table
          padding="extra_small"
          border="medium"
          rows={@messages.results}
          table_body_class="[&_div.whitespace-nowrap]:py-1.5 [&_td.relative.w-14]:w-24"
        >
          <:col :let={message} label="From">
            <span class={[
              if(!message.received, do: "font-semibold")
            ]}>
              {message_sender_name(message)}
            </span>
          </:col>
          <:col :let={message} label="Type">
            <span class="text-xs text-base-content/70">
              {message_type_label(message)}
            </span>
          </:col>
          <:col :let={message} label="Message">
            <.popover
              id={"message-popover-#{message.id}"}
              width="double_large"
              variant="default"
              color="dark"
              show_delay={400}
            >
              <:trigger class={message_trigger_class(message)}>
                {message_preview(message)}
              </:trigger>
              <:content class="text-sm whitespace-pre-line">
                <%= if shared_video_message?(message) do %>
                  <div class="mb-2 text-base-content/70">
                    {shared_video_summary(message)}
                  </div>
                <% end %>
                <%= if message_body_present?(message) do %>
                  <div class="whitespace-pre-line">{message.body}</div>
                <% end %>
                <%= if message.shared_video do %>
                  <div class="mt-3 pt-3 border-t border-gray-600">
                    <.link
                      navigate={~p"/videos/#{message.shared_video.id}"}
                      class="inline-flex items-center gap-1 text-blue-400 hover:text-blue-300"
                    >
                      <.icon name="hero-play-circle" class="w-4 h-4" />
                      Watch: {message.shared_video.title}
                    </.link>
                  </div>
                <% end %>
              </:content>
            </.popover>
          </:col>
          <:col :let={message} label="Date">
            <span class={message.received && "text-base-content/80"}>
              {Calendar.strftime(message.inserted_at, "%b %d, %Y %H:%M")}
            </span>
          </:col>
          <:action :let={message}>
            <div class="flex items-center gap-2">
              <%= if message.received do %>
                <span class="text-green-500 p-1">
                  <.icon name="hero-check-badge" class="w-5 h-5" />
                </span>
              <% else %>
                <.tooltip
                  id={"mark-read-table-#{message.id}"}
                  position="left"
                  color="dark"
                >
                  <:trigger>
                    <button
                      type="button"
                      phx-click="mark_message_read"
                      phx-value-id={message.id}
                      phx-target={@myself}
                      class="text-gray-500 hover:text-green-600 transition-colors p-1"
                    >
                      <.icon name="hero-check-badge" class="w-5 h-5" />
                    </button>
                  </:trigger>
                  <:content>Mark as read</:content>
                </.tooltip>
              <% end %>
              <button
                id={"message-delete-#{message.id}"}
                type="button"
                phx-click="delete_message"
                phx-value-id={message.id}
                phx-target={@myself}
                data-confirm="Are you sure you want to delete this message? This action cannot be undone."
                class="p-1 text-error cursor-pointer hover:bg-error/10 rounded-full transition-colors"
              >
                <.icon name="hero-trash" class="w-5 h-5" />
              </button>
            </div>
          </:action>
        </.table>

        <%= if @messages.count > 10 do %>
          <div class="mt-4 flex justify-center">
            <.pagination
              total={ceil(@messages.count / 10)}
              active={@messages_page}
              siblings={1}
              phx-click="messages_pagination"
              phx-target={@myself}
            />
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
