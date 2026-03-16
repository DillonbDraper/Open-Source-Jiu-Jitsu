defmodule FosBjjWeb.Components.NotesListComponent do
  @moduledoc """
  LiveComponent for displaying paginated, searchable user notes as expandable cards.
  """
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.VideoNote
  import FosBjjWeb.Components.Card
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  import FosBjjWeb.Components.RadioField
  import FosBjjWeb.Components.ScrollArea
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
     |> assign(:expanded_note_ids, [])
     |> assign(:deleted_notes_toggle_form, to_form(%{}))}
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
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search_notes_input", %{"value" => query}, socket) when is_binary(query) do
    {:noreply, apply_search_query(socket, query)}
  end

  def handle_event("search_notes_input", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("pagination", params, socket) do
    paginate_notes(params, socket)
  end

  @impl true
  def handle_event("toggle_note", %{"id" => id}, socket) do
    note_id = normalize_note_id(id)
    expanded_note_ids = socket.assigns.expanded_note_ids

    updated_expanded_ids =
      if note_id in expanded_note_ids do
        List.delete(expanded_note_ids, note_id)
      else
        [note_id | expanded_note_ids]
      end

    {:noreply, assign(socket, :expanded_note_ids, updated_expanded_ids)}
  end

  @impl true
  def handle_event("collapse_note", %{"id" => id}, socket) do
    note_id = normalize_note_id(id)
    updated_expanded_ids = List.delete(socket.assigns.expanded_note_ids, note_id)
    {:noreply, assign(socket, :expanded_note_ids, updated_expanded_ids)}
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
         |> assign(:expanded_note_ids, List.delete(socket.assigns.expanded_note_ids, note_id))
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
     |> assign(:notes, notes)
     |> assign(:expanded_note_ids, [])}
  end

  defp paginate_notes(params, socket) do
    current_page = socket.assigns.notes_page || 1
    total_pages = ceil(socket.assigns.notes.count / 10)

    page_param =
      case params["action"] do
        "select" -> params["page"]
        "next" -> min(current_page + 1, total_pages)
        "previous" -> max(current_page - 1, 1)
        "first" -> 1
        "last" -> total_pages
        _ -> params["page"] || current_page
      end

    page = normalize_page(page_param, current_page)

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
     |> assign(:notes_page, page)
     |> assign(:expanded_note_ids, [])}
  end

  defp apply_search_query(socket, query) do
    page = 1

    notes =
      list_user_notes(
        socket.assigns.current_user,
        query,
        page,
        socket.assigns.show_deleted_video_notes
      )

    socket
    |> assign(:notes_search_query, query)
    |> assign(:notes, notes)
    |> assign(:notes_page, page)
    |> assign(:expanded_note_ids, [])
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

  defp normalize_note_id(id) when is_integer(id), do: id
  defp normalize_note_id(id) when is_binary(id), do: String.to_integer(id)
  defp normalize_note_id(id), do: id

  defp normalize_page(page, _fallback) when is_integer(page), do: page

  defp normalize_page(page, fallback) when is_binary(page) do
    case Integer.parse(page) do
      {parsed, ""} -> parsed
      _ -> fallback
    end
  end

  defp normalize_page(_, fallback), do: fallback

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="h-full flex flex-col rounded-lg border border-base-200 bg-base-100 shadow-sm overflow-hidden"
    >
      <div class="border-b border-base-200 p-4 space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-4">
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

        <.search_field
          id={"#{@id}-search"}
          name="query"
          value={@notes_search_query}
          placeholder="Search by note body or video title..."
          phx-keyup="search_notes_input"
          phx-target={@myself}
          phx-debounce="500"
        />
      </div>

      <.scroll_area id={"#{@id}-notes-scroll"} class="flex-1 w-full" height="h-full">
        <%= if @notes.results == [] do %>
          <div
            id={"#{@id}-empty-state"}
            class="h-full flex items-center justify-center p-6"
          >
            <div class="rounded-xl border border-dashed border-base-200 bg-base-50 px-4 py-10 text-center w-full">
              <.p class="text-sm text-base-content/70">You have no notes taken.</.p>
            </div>
          </div>
        <% else %>
          <div class="space-y-3 p-4">
            <%= for note <- @notes.results do %>
              <%= if note.id in @expanded_note_ids do %>
                <.card
                  class="relative border border-base-300/60 rounded-xl"
                  color="base"
                  variant="default"
                >
                  <.card_content class="pl-4 pr-3 py-3">
                    <div class="flex items-start gap-2.5">
                      <button
                        id={"#{@id}-collapse-note-#{note.id}"}
                        type="button"
                        phx-click="collapse_note"
                        phx-target={@myself}
                        phx-value-id={note.id}
                        class="p-1.5 text-base-content/50 hover:text-base-content rounded-full transition-colors shrink-0 mt-0.5"
                        aria-label="Collapse note"
                      >
                        <.icon name="hero-chevron-up" class="w-5 h-5" />
                      </button>

                      <div class="min-w-0 flex-1">
                        <div class="flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
                          <%= if note_video_deleted?(note) do %>
                            <span class="inline-flex items-center gap-1 text-sm text-base-content/50 line-through min-w-0">
                              <.icon name="hero-no-symbol" class="w-4 h-4 shrink-0" />
                              <span class="truncate">{note.video.title}</span>
                            </span>
                          <% else %>
                            <.link
                              navigate={~p"/videos/#{note.video_id}"}
                              class="inline-flex items-center gap-1 text-sm font-semibold text-blue-600 hover:underline min-w-0"
                            >
                              <.icon name="hero-video-camera" class="w-4 h-4 shrink-0" />
                              <span class="truncate">{note.video.title}</span>
                            </.link>
                          <% end %>

                          <span class="text-xs text-base-content/60 whitespace-nowrap">
                            {Calendar.strftime(note.inserted_at, "%b %d, %Y %I:%M %p")}
                          </span>
                        </div>

                        <div class="mt-2 whitespace-pre-wrap text-sm leading-relaxed text-base-content">
                          {note.body}
                        </div>

                        <div class="mt-3 pt-2 border-t border-base-200 flex items-center justify-between gap-2">
                          <%= if note_video_deleted?(note) do %>
                            <span class="inline-flex items-center gap-1 text-base-content/50 text-sm font-mono">
                              <.icon name="hero-lock-closed" class="w-4 h-4" />
                              {format_timestamp(note.video_timestamp)}
                            </span>
                          <% else %>
                            <.link
                              navigate={~p"/videos/#{note.video_id}?time=#{note.video_timestamp}"}
                              class="inline-flex items-center gap-1 text-blue-600 hover:underline text-sm font-mono"
                            >
                              <.icon name="hero-play" class="w-4 h-4" />
                              {format_timestamp(note.video_timestamp)}
                            </.link>
                          <% end %>

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
                            <.icon name="hero-trash" class="w-4 h-4" />
                          </.button>
                        </div>
                      </div>
                    </div>
                  </.card_content>
                </.card>
              <% else %>
                <.card
                  class="relative border border-base-300/60 rounded-xl"
                  color="base"
                  variant="default"
                >
                  <.card_content class="pl-4 pr-3 py-3">
                    <div class="flex items-start gap-2.5">
                      <button
                        id={"#{@id}-toggle-note-#{note.id}"}
                        type="button"
                        phx-click="toggle_note"
                        phx-target={@myself}
                        phx-value-id={note.id}
                        class="p-1.5 text-base-content/50 hover:text-base-content rounded-full transition-colors shrink-0 mt-0.5"
                        aria-label="Expand note"
                      >
                        <.icon name="hero-chevron-down" class="w-5 h-5" />
                      </button>

                      <div class="min-w-0 flex-1">
                        <div class="flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
                          <%= if note_video_deleted?(note) do %>
                            <span class="inline-flex items-center gap-1 text-sm text-base-content/50 line-through min-w-0">
                              <.icon name="hero-no-symbol" class="w-4 h-4 shrink-0" />
                              <span class="truncate">{note.video.title}</span>
                            </span>
                          <% else %>
                            <.link
                              navigate={~p"/videos/#{note.video_id}"}
                              class="inline-flex items-center gap-1 text-sm font-semibold text-blue-600 hover:underline min-w-0"
                            >
                              <.icon name="hero-video-camera" class="w-4 h-4 shrink-0" />
                              <span class="truncate">{note.video.title}</span>
                            </.link>
                          <% end %>

                          <%= if note_video_deleted?(note) do %>
                            <span class="inline-flex items-center gap-1 text-base-content/50 text-sm font-mono whitespace-nowrap">
                              <.icon name="hero-lock-closed" class="w-4 h-4" />
                              {format_timestamp(note.video_timestamp)}
                            </span>
                          <% else %>
                            <.link
                              navigate={~p"/videos/#{note.video_id}?time=#{note.video_timestamp}"}
                              class="inline-flex items-center gap-1 text-blue-600 hover:underline text-sm font-mono whitespace-nowrap"
                            >
                              <.icon name="hero-play" class="w-4 h-4" />
                              {format_timestamp(note.video_timestamp)}
                            </.link>
                          <% end %>
                        </div>

                        <button
                          type="button"
                          phx-click="toggle_note"
                          phx-target={@myself}
                          phx-value-id={note.id}
                          class="mt-1 w-full text-left"
                        >
                          <span class="block truncate text-sm text-base-content/80">{note.body}</span>
                        </button>
                      </div>
                    </div>
                  </.card_content>
                </.card>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </.scroll_area>

      <%= if @notes.count > 10 do %>
        <div class="p-4 border-t border-base-200 bg-base-100 flex justify-center">
          <.pagination
            total={ceil(@notes.count / 10)}
            active={@notes_page}
            siblings={1}
            target={@myself}
          />
        </div>
      <% end %>
    </div>
    """
  end
end
