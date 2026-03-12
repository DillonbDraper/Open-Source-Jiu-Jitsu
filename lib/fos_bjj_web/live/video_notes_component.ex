defmodule FosBjjWeb.VideoNotesComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.VideoNote
  import FosBjjWeb.Components.Card
  alias FosBjjWeb.Components.Modal
  import FosBjjWeb.Components.Button
  import FosBjjWeb.Components.Icon
  import FosBjjWeb.Components.ScrollArea

  require Ash.Query

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign_new(:show_modal, fn -> false end)
      |> assign_new(:form, fn -> to_form(%{"body" => "", "minutes" => 0, "seconds" => 0}) end)
      |> assign_new(:notes, fn -> [] end)
      |> assign_new(:expanded_note_ids, fn -> [] end)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket = maybe_sync_form_timestamp(socket, assigns[:current_time])

    socket =
      if socket.assigns[:video_id] != socket.assigns[:notes_video_id] do
        socket
        |> assign(:notes_video_id, socket.assigns.video_id)
        |> assign(:expanded_note_ids, [])
        |> load_notes()
      else
        socket
      end

    {:ok, socket}
  end

  defp load_notes(socket) do
    if socket.assigns[:video_id] && socket.assigns[:current_user] do
      notes =
        VideoNote
        |> Ash.Query.filter(
          video_id == ^socket.assigns.video_id and user_id == ^socket.assigns.current_user.id
        )
        |> Ash.Query.sort(video_timestamp: :asc_nils_first)
        |> Ash.Query.for_read(:read_all)
        |> Ash.read!(page: false)

      assign(socket, :notes, notes)
    else
      assign(socket, :notes, [])
    end
  end

  @impl true
  def handle_event("add_note", _, socket) do
    minutes = div(socket.assigns.current_time, 60)
    seconds = rem(socket.assigns.current_time, 60)

    send(self(), {:request_player_status})

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:form, to_form(%{"body" => "", "minutes" => minutes, "seconds" => seconds}))}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
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
  def handle_event(
        "save_note",
        %{"body" => body, "minutes" => minutes, "seconds" => seconds},
        socket
      ) do
    timestamp = (parse_timestamp(minutes) || 0) * 60 + (parse_timestamp(seconds) || 0)

    params = %{
      video_id: socket.assigns.video_id,
      body: body,
      video_timestamp: timestamp
    }

    case create_note(params, socket.assigns.current_user) do
      {:ok, _note} ->
        socket =
          socket
          |> assign(:show_modal, false)
          |> assign(:form, to_form(%{"body" => "", "minutes" => 0, "seconds" => 0}))
          |> load_notes()
          |> put_flash(:success, "Note added successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :danger, "Could not save note")}
    end
  end

  @impl true
  def handle_event("seek_video", %{"seconds" => seconds}, socket) do
    seconds = String.to_integer(seconds)
    send(self(), {:seek_video, seconds})
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_note", %{"id" => id}, socket) do
    note_id = normalize_note_id(id)
    note = Ash.get!(VideoNote, note_id)

    case Ash.destroy(note) do
      :ok ->
        {:noreply,
         socket
         |> assign(:expanded_note_ids, List.delete(socket.assigns.expanded_note_ids, note_id))
         |> load_notes()
         |> put_flash(:success, "Note deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :danger, "Could not delete note")}
    end
  end

  defp create_note(params, user) do
    VideoNote
    |> Ash.Changeset.for_create(:create, params, actor: user)
    |> Ash.create()
  end

  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(""), do: nil
  defp parse_timestamp(val) when is_integer(val), do: val
  defp parse_timestamp(val) when is_binary(val), do: String.to_integer(val)

  defp normalize_note_id(id) when is_integer(id), do: id
  defp normalize_note_id(id) when is_binary(id), do: String.to_integer(id)
  defp normalize_note_id(id), do: id

  defp maybe_sync_form_timestamp(socket, current_time) do
    if socket.assigns[:show_modal] == true do
      existing_body =
        case socket.assigns.form.params do
          %{"body" => body} -> body
          _ -> ""
        end

      minutes = div(current_time, 60)
      seconds = rem(current_time, 60)

      assign(
        socket,
        :form,
        to_form(%{"body" => existing_body, "minutes" => minutes, "seconds" => seconds})
      )
    else
      socket
    end
  end

  defp format_timestamp(nil), do: "--:--"

  defp format_timestamp(seconds) do
    minutes = div(seconds, 60)
    rem_seconds = rem(seconds, 60)
    padded_seconds = String.pad_leading("#{rem_seconds}", 2, "0")
    "#{minutes}:#{padded_seconds}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-2 h-[calc(70vh-4rem)] flex flex-col gap-2 rounded-lg border border-base-200/80 bg-base-100 p-2 shadow-sm">
      <div class="flex justify-end mb-1">
        <.button phx-click="add_note" phx-target={@myself} color="primary" size="small">
          <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Add Note
        </.button>
      </div>

      <.scroll_area id="video-notes-scroll" class="flex-1 w-full" height="h-full">
        <div class="space-y-2 pr-1">
          <%= for note <- @notes do %>
            <%= if note.id in @expanded_note_ids do %>
              <.card
                class="relative border border-base-300/60 rounded-xl"
                color="base"
                variant="default"
              >
                <.card_content class="pl-4 pr-3 py-2">
                  <div class="flex items-start gap-2.5">
                    <button
                      type="button"
                      phx-click="collapse_note"
                      phx-target={@myself}
                      phx-value-id={note.id}
                      class="p-1.5 text-base-content/50 hover:text-base-content rounded-full transition-colors shrink-0 mt-0.5"
                      aria-label="Collapse note"
                    >
                      <.icon name="hero-chevron-up" class="w-5 h-5" />
                    </button>
                    <div class="flex-1 min-w-0">
                      <div class="whitespace-pre-wrap text-base leading-relaxed">{note.body}</div>
                      <div class="flex items-center justify-between mt-2 pt-2 border-t border-base-200">
                        <%= if note.video_timestamp do %>
                          <.button
                            type="button"
                            variant="transparent"
                            size="extra_small"
                            class="font-mono text-base text-blue-600 hover:underline whitespace-nowrap cursor-pointer"
                            phx-click="seek_video"
                            phx-target={@myself}
                            phx-value-seconds={note.video_timestamp}
                          >
                            <.icon name="hero-play" class="w-3.5 h-3.5 mr-1" />
                            {format_timestamp(note.video_timestamp)}
                          </.button>
                        <% else %>
                          <div class="font-mono text-base text-base-content/70 whitespace-nowrap">
                            {format_timestamp(note.video_timestamp)}
                          </div>
                        <% end %>
                        <.button
                          type="button"
                          variant="transparent"
                          size="extra_small"
                          phx-click="delete_note"
                          phx-target={@myself}
                          phx-value-id={note.id}
                          data-confirm="This note will be permanently deleted. Are you certain?"
                          class="p-1 text-error hover:bg-error/10 rounded-full transition-colors"
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
                <.card_content class="pl-4 pr-3 py-2">
                  <div class="flex items-center gap-2.5">
                    <button
                      type="button"
                      phx-click="toggle_note"
                      phx-target={@myself}
                      phx-value-id={note.id}
                      class="flex items-center gap-2.5 min-w-0 flex-1 text-left cursor-pointer"
                      aria-label="Expand note"
                    >
                      <.icon
                        name="hero-chevron-down"
                        class="w-5 h-5 text-base-content/50 shrink-0"
                      />
                      <span class="min-w-0 truncate text-base">{note.body}</span>
                    </button>

                    <%= if note.video_timestamp do %>
                      <.button
                        type="button"
                        variant="transparent"
                        size="extra_small"
                        class="font-mono text-sm text-blue-600 hover:underline whitespace-nowrap cursor-pointer shrink-0"
                        phx-click="seek_video"
                        phx-target={@myself}
                        phx-value-seconds={note.video_timestamp}
                      >
                        {format_timestamp(note.video_timestamp)}
                      </.button>
                    <% else %>
                      <div class="font-mono text-sm text-base-content/70 whitespace-nowrap shrink-0">
                        {format_timestamp(note.video_timestamp)}
                      </div>
                    <% end %>
                  </div>
                </.card_content>
              </.card>
            <% end %>
          <% end %>

          <%= if @notes == [] do %>
            <div class="text-center text-base-content/50 py-8 text-sm">
              No notes yet. Click "Add Note" to get started.
            </div>
          <% end %>
        </div>
      </.scroll_area>

      <Modal.modal
        :if={@show_modal}
        id="add-note-modal"
        show={@show_modal}
        title="Add New Note"
        on_cancel={JS.push("close_modal", target: @myself)}
      >
        <div class="p-1">
          <.form for={@form} phx-submit="save_note" phx-target={@myself} class="flex flex-col gap-4">
            <div class="flex items-end gap-2">
              <div class="flex-1">
                <.input
                  field={@form[:minutes]}
                  type="number"
                  label="Min"
                  placeholder="0"
                  min="0"
                />
              </div>
              <div class="pb-3 font-bold text-lg">:</div>
              <div class="flex-1">
                <.input
                  field={@form[:seconds]}
                  type="number"
                  label="Sec"
                  placeholder="00"
                  min="0"
                  max="59"
                />
              </div>
            </div>

            <.input
              field={@form[:body]}
              type="textarea"
              label="Note"
              placeholder="Enter your note here..."
              required
              class="h-24"
            />

            <div class="modal-action">
              <.button type="button" color="ghost" phx-click="close_modal" phx-target={@myself}>
                Cancel
              </.button>
              <.button type="submit" color="primary">Save Note</.button>
            </div>
          </.form>
        </div>
      </Modal.modal>
    </div>
    """
  end
end
