defmodule FosBjjWeb.Components.SentMessagesTable do
  @moduledoc """
  LiveComponent for displaying grouped sent messages with recipient details.
  """
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.UserMessage
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  require Ash.Query

  @page_size 10

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:sent_messages, nil)
     |> assign(:sent_messages_page, 1)
     |> assign(:sent_messages_search_query, "")}
  end

  @impl true
  def update(%{current_user: user} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns.sent_messages == nil do
        messages = list_sent_message_groups(user, "", 1)
        assign(socket, :sent_messages, messages)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search_sent_messages", %{"query" => query}, socket) do
    page = 1
    messages = list_sent_message_groups(socket.assigns.current_user, query, page)

    {:noreply,
     socket
     |> assign(:sent_messages_search_query, query)
     |> assign(:sent_messages, messages)
     |> assign(:sent_messages_page, page)}
  end

  @impl true
  def handle_event("sent_messages_pagination", params, socket) do
    current_page = socket.assigns.sent_messages_page || 1
    total_pages = max(ceil(socket.assigns.sent_messages.count / @page_size), 1)

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
      list_sent_message_groups(
        socket.assigns.current_user,
        socket.assigns.sent_messages_search_query,
        page
      )

    {:noreply,
     socket
     |> assign(:sent_messages, messages)
     |> assign(:sent_messages_page, page)}
  end

  defp list_sent_message_groups(user, query, page) do
    offset = (page - 1) * @page_size

    groups =
      user
      |> sent_messages_query(query)
      |> Ash.read!(actor: user)
      |> Enum.group_by(& &1.message_group_id)
      |> Enum.map(fn {group_id, messages} ->
        representative = hd(messages)

        recipients =
          messages
          |> Enum.map(&%{id: &1.recipient_id, name: recipient_name(&1), received: &1.received})
          |> Enum.sort_by(&String.downcase(&1.name))

        %{
          id: group_id,
          message_group_id: group_id,
          type: representative.type,
          body: representative.body,
          shared_video: representative.shared_video,
          inserted_at: representative.inserted_at,
          recipient_count: length(messages),
          recipients: recipients
        }
      end)
      |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

    %{results: Enum.slice(groups, offset, @page_size), count: length(groups)}
  end

  defp sent_messages_query(user, query) do
    UserMessage
    |> Ash.Query.filter(sender_id == ^user.id)
    |> Ash.Query.load([:shared_video, :recipient])
    |> then(fn q ->
      if query != "" do
        query_string = "%#{query}%"

        Ash.Query.filter(
          q,
          (not is_nil(body) and ilike(body, ^query_string)) or
            (not is_nil(shared_video_id) and ilike(shared_video.title, ^query_string))
        )
      else
        q
      end
    end)
    |> Ash.Query.sort(inserted_at: :desc)
  end

  defp recipient_name(%{recipient: nil}), do: "Unknown recipient"

  defp recipient_name(%{recipient: recipient}) do
    recipient.user_name || recipient.email || "Unknown recipient"
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

  defp message_preview(message) do
    cond do
      message_body_present?(message) -> message.body
      shared_video_message?(message) -> "Video shared"
      true -> "System notification"
    end
  end

  defp page_size, do: @page_size

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="card bg-base-100 shadow-sm border border-base-200 p-6">
      <.h3 class="text-lg font-medium mb-4">Sent Messages</.h3>
      <%= if @sent_messages.results == [] do %>
        <div
          id="sent-messages-empty-state"
          class="rounded-xl border border-dashed border-base-200 bg-base-50 px-4 py-10 text-center"
        >
          <.p class="text-sm text-base-content/70">You have not sent any messages.</.p>
        </div>
      <% else %>
        <div class="mb-4">
          <form
            phx-change="search_sent_messages"
            phx-submit="search_sent_messages"
            phx-target={@myself}
          >
            <.search_field
              name="query"
              value={@sent_messages_search_query}
              placeholder="Search sent messages..."
              phx-change="search_sent_messages"
              phx-target={@myself}
              phx-debounce="400"
            />
          </form>
        </div>

        <.table
          padding="extra_small"
          border="medium"
          rows={@sent_messages.results}
          table_body_class="[&_div.whitespace-nowrap]:py-1.5 [&_td.relative.w-14]:w-28"
        >
          <:col :let={message} label="Type">
            <span class="text-xs text-base-content/70">
              {message_type_label(message)}
            </span>
          </:col>
          <:col :let={message} label="Message">
            <.popover
              id={"sent-message-popover-#{message.message_group_id}"}
              width="double_large"
              variant="default"
              color="dark"
              show_delay={400}
            >
              <:trigger class="truncate max-w-xs cursor-help block">
                {message_preview(message)}
              </:trigger>
              <:content class="text-sm whitespace-pre-line">
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
            {Calendar.strftime(message.inserted_at, "%b %d, %Y %H:%M")}
          </:col>
          <:col :let={message} label="Recipients">
            <.popover
              id={"sent-recipients-popover-#{message.message_group_id}"}
              clickable
              position="bottom"
              width="large"
              variant="base"
            >
              <:trigger>
                <.button
                  type="button"
                  variant="transparent"
                  class="inline-flex items-center gap-2 px-2 py-1 rounded-md text-base-content hover:bg-base-200"
                >
                  <span>{message.recipient_count}</span>
                  <.icon name="hero-chevron-down" class="w-4 h-4" />
                </.button>
              </:trigger>
              <:content class="min-w-56 text-sm text-slate-800">
                <%= case message.recipients do %>
                  <% [] -> %>
                    <div class="text-xs text-slate-500">No recipients found.</div>
                  <% recipients -> %>
                    <div class="space-y-2">
                      <%= for recipient <- recipients do %>
                        <div class="flex items-center justify-between gap-3 text-sm">
                          <span class="truncate text-slate-900">{recipient.name}</span>
                          <span class={[
                            "inline-flex items-center gap-1 text-xs",
                            recipient.received && "text-emerald-600",
                            !recipient.received && "text-amber-600"
                          ]}>
                            <.icon
                              name={
                                if recipient.received, do: "hero-check-circle", else: "hero-clock"
                              }
                              class="w-4 h-4"
                            />
                            {if recipient.received, do: "Read", else: "Unread"}
                          </span>
                        </div>
                      <% end %>
                    </div>
                <% end %>
              </:content>
            </.popover>
          </:col>
        </.table>

        <%= if @sent_messages.count > page_size() do %>
          <div class="mt-4 flex justify-center">
            <.pagination
              total={ceil(@sent_messages.count / page_size())}
              active={@sent_messages_page}
              siblings={1}
              phx-click="sent_messages_pagination"
              phx-target={@myself}
            />
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
