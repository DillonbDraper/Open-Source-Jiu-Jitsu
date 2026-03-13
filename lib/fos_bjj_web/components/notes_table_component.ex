defmodule FosBjjWeb.Components.NotesTableComponent do
  @moduledoc """
  LiveComponent for displaying a paginated, searchable table of user notes.
  """
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.VideoNote
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  import FosBjjWeb.Components.RadioField
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:notes, nil)
     |> assign(:notes_page, 1)
     |> assign(:notes_search_query, "")
     |> assign(:show_deleted_video_notes, false)
     |> assign(:has_deleted_video_notes, false)
     |> assign(:deleted_notes_toggle_form, to_form(%{}))
     |> assign(:search_form, to_form(%{"query" => ""}, as: :notes_search))}
  end

  @impl true
  def update(%{current_user: user} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns.notes == nil do
        {notes, has_deleted_video_notes} =
          list_user_notes_with_deleted_flag(user, "", 1, socket.assigns.show_deleted_video_notes)

        socket
        |> assign(:notes, notes)
        |> assign(:has_deleted_video_notes, has_deleted_video_notes)
        |> assign(:search_form, to_form(%{"query" => ""}, as: :notes_search))
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search_notes", %{"notes_search" => %{"query" => query}}, socket) do
    page = 1

    notes =
      list_user_notes(
        socket.assigns.current_user,
        query,
        page,
        socket.assigns.show_deleted_video_notes
      )

    {:noreply,
     socket
     |> assign(:notes_search_query, query)
     |> assign(:notes, notes)
     |> assign(:notes_page, page)
     |> assign(:search_form, to_form(%{"query" => query}, as: :notes_search))}
  end

  @impl true
  def handle_event("notes_pagination", params, socket) do
    current_page = socket.assigns.notes_page || 1
    total_pages = ceil(socket.assigns.notes.count / 10)

    page =
      case params["action"] do
        "select" -> params["page"]
        "next" -> min(current_page + 1, total_pages)
        "previous" -> max(current_page - 1, 1)
        "first" -> 1
        "last" -> total_pages
        _ -> params["page"] || current_page
      end

    notes =
      list_user_notes(
        socket.assigns.current_user,
        socket.assigns.notes_search_query,
        page,
        socket.assigns.show_deleted_video_notes
      )

    {:noreply,
     socket
     |> assign(:notes, notes)
     |> assign(:notes_page, page)}
  end

  @impl true
  def handle_event("delete_note", %{"id" => id}, socket) do
    note_id = String.to_integer(id)
    user = socket.assigns.current_user

    note = Ash.get!(VideoNote, note_id, actor: user)

    case Ash.destroy(note, actor: user) do
      :ok ->
        page = socket.assigns.notes_page
        query = socket.assigns.notes_search_query

        {notes, has_deleted_video_notes} =
          list_user_notes_with_deleted_flag(
            user,
            query,
            page,
            socket.assigns.show_deleted_video_notes
          )

        show_deleted_video_notes =
          socket.assigns.show_deleted_video_notes && has_deleted_video_notes

        {notes, page} =
          if notes.results == [] && page > 1 do
            new_page = 1

            {list_user_notes(user, query, new_page, show_deleted_video_notes), new_page}
          else
            {notes, page}
          end

        {:noreply,
         socket
         |> assign(:notes, notes)
         |> assign(:notes_page, page)
         |> assign(:show_deleted_video_notes, show_deleted_video_notes)
         |> assign(:has_deleted_video_notes, has_deleted_video_notes)
         |> put_flash(:success, "Note deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :danger, "Could not delete note")}
    end
  end

  @impl true
  def handle_event(
        "set_deleted_notes_visibility",
        %{"show_deleted_video_notes" => visibility},
        socket
      ) do
    show_deleted_video_notes = visibility == "true"
    page = 1

    {notes, has_deleted_video_notes} =
      list_user_notes_with_deleted_flag(
        socket.assigns.current_user,
        socket.assigns.notes_search_query,
        page,
        show_deleted_video_notes
      )

    show_deleted_video_notes = show_deleted_video_notes && has_deleted_video_notes

    {:noreply,
     socket
     |> assign(:show_deleted_video_notes, show_deleted_video_notes)
     |> assign(:has_deleted_video_notes, has_deleted_video_notes)
     |> assign(:notes_page, page)
     |> assign(:notes, notes)}
  end

  defp list_user_notes_with_deleted_flag(user, query, page, show_deleted_video_notes) do
    notes = list_user_notes(user, query, page, show_deleted_video_notes)
    {notes, has_deleted_video_notes?(user)}
  end

  defp list_user_notes(user, query, page, show_deleted_video_notes) do
    offset = (page - 1) * 10

    query_base =
      VideoNote
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.load(:video)
      |> then(fn q ->
        if show_deleted_video_notes do
          q
        else
          Ash.Query.filter(q, is_nil(video.deleted_at))
        end
      end)

    query_base
    |> then(fn q ->
      if query != "" do
        query_string = "%#{query}%"
        # This is extremely ugly and the docs lie than that Ash.Query.Contain is case insensitive
        Ash.Query.filter(
          q,
          ilike(body, ^query_string) or
            ilike(video.title, ^query_string)
        )
      else
        q
      end
    end)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: user, page: [limit: 10, offset: offset, count: true])
  end

  defp note_video_deleted?(note) do
    case note.video do
      %{deleted_at: nil} -> false
      _ -> true
    end
  end

  defp has_deleted_video_notes?(user) do
    VideoNote
    |> Ash.Query.for_read(:read_all)
    |> Ash.Query.filter(user_id == ^user.id and not is_nil(video.deleted_at))
    |> Ash.Query.load(:video)
    |> Ash.Query.limit(1)
    |> Ash.read!(actor: user)
    |> Enum.any?()
  end

  defp format_timestamp(nil), do: "--:--"

  defp format_timestamp(seconds) when is_integer(seconds) do
    min = div(seconds, 60)
    sec = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [min, sec]) |> to_string()
  end

  defp format_timestamp(_), do: "--:--"

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="card bg-base-100 shadow-sm border border-base-200 p-6">
      <div class="mb-4 flex items-center justify-between gap-4">
        <.h3 class="text-lg font-medium">My Notes</.h3>
        <.form
          :if={@has_deleted_video_notes}
          for={@deleted_notes_toggle_form}
          id={"#{@id}-deleted-toggle-form"}
          phx-change="set_deleted_notes_visibility"
          phx-target={@myself}
        >
          <.group_radio
            id={"#{@id}-deleted-toggle"}
            name="show_deleted_video_notes"
            variation="horizontal"
            space="small"
            color="primary"
            size="small"
          >
            <:radio value="false" checked={!@show_deleted_video_notes}>
              Hide deleted video notes
            </:radio>
            <:radio value="true" checked={@show_deleted_video_notes}>
              Show deleted video notes
            </:radio>
          </.group_radio>
        </.form>
      </div>
      <%= if @notes.results == [] do %>
        <div
          id={"#{@id}-empty-state"}
          class="rounded-xl border border-dashed border-base-200 bg-base-50 px-4 py-10 text-center"
        >
          <.p class="text-sm text-base-content/70">You have no notes taken.</.p>
        </div>
      <% else %>
        <div class="mb-4">
          <.form
            for={@search_form}
            id={"#{@id}-search-form"}
            phx-change="search_notes"
            phx-submit="search_notes"
            phx-target={@myself}
          >
            <.search_field
              field={@search_form[:query]}
              id={"#{@id}-search"}
              placeholder="Search by note body or video title..."
              phx-debounce="400"
            />
          </.form>
        </div>

        <.table
          id={"#{@id}-table"}
          padding="extra_small"
          border="medium"
          rows={@notes.results}
          table_body_class="[&_div.whitespace-nowrap]:py-1.5 [&_td.relative.w-14]:w-24"
        >
          <:col :let={note} label="Video">
            <%= if note_video_deleted?(note) do %>
              <span class="inline-flex items-center gap-1 text-base-content/50 line-through">
                <.icon name="hero-no-symbol" class="w-4 h-4" /> note.video.title
              </span>
            <% else %>
              <.link
                navigate={~p"/videos/#{note.video_id}"}
                class="link link-primary font-semibold text-blue-600"
              >
                {note.video.title}
              </.link>
            <% end %>
          </:col>
          <:col :let={note} label="Note">
            <.popover
              id={"note-popover-#{note.id}"}
              width="double_large"
              variant="default"
              color="dark"
              show_delay={400}
            >
              <:trigger class="truncate max-w-xs cursor-help block">
                {note.body}
              </:trigger>
              <:content class="text-sm">
                {note.body}
              </:content>
            </.popover>
          </:col>
          <:col :let={note} label="Timestamp">
            <%= if note_video_deleted?(note) do %>
              <span class="inline-flex items-center gap-1 text-base-content/50">
                <.icon name="hero-lock-closed" class="w-4 h-4" />
                {format_timestamp(note.video_timestamp)}
              </span>
            <% else %>
              <.link
                navigate={~p"/videos/#{note.video_id}?time=#{note.video_timestamp}"}
                class="link link-primary font-semibold text-blue-600"
              >
                {format_timestamp(note.video_timestamp)}
              </.link>
            <% end %>
          </:col>
          <:col :let={note} label="Created">
            {Calendar.strftime(note.inserted_at, "%b %d, %Y %H:%M %p")}
          </:col>
          <:action :let={note}>
            <.button
              id={"#{@id}-delete-note-#{note.id}"}
              type="button"
              variant="transparent"
              phx-click="delete_note"
              phx-value-id={note.id}
              phx-target={@myself}
              data-confirm="Are you sure you want to delete this note? This action cannot be undone."
              class="p-1 text-error hover:bg-error/10 cursor-pointer rounded-full transition-colors"
              aria-label="Delete note"
            >
              <.icon name="hero-trash" class="w-5 h-5" />
            </.button>
          </:action>
        </.table>

        <%= if @notes.count > 10 do %>
          <div class="mt-4 flex justify-center">
            <.pagination
              total={ceil(@notes.count / 10)}
              active={@notes_page}
              siblings={1}
              phx-click="notes_pagination"
              phx-target={@myself}
            />
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
