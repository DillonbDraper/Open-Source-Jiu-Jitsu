defmodule FosBjjWeb.VideoNotesComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.VideoNote
  import FosBjjWeb.Components.Card
  alias FosBjjWeb.Components.Modal
  import FosBjjWeb.Components.Button
  import FosBjjWeb.Components.Icon

  require Ash.Query

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign_new(:show_modal, fn -> false end)
      |> assign_new(:form, fn -> to_form(%{"body" => "", "video_timestamp" => nil}) end)
      |> load_notes()

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
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
    {:noreply,
     socket
     |> push_event("request_player_status", %{})
     |> assign(:show_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("save_note", %{"body" => body, "video_timestamp" => timestamp}, socket) do
    params = %{
      video_id: socket.assigns.video_id,
      body: body,
      video_timestamp: parse_timestamp(timestamp)
    }

    case create_note(params, socket.assigns.current_user) do
      {:ok, _note} ->
        socket =
          socket
          |> assign(:show_modal, false)
          |> assign(:form, to_form(%{"body" => "", "video_timestamp" => nil}))
          |> load_notes()
          |> put_flash(:info, "Note added successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save note")}
    end
  end

  @impl true
  def handle_event("seek_video", %{"seconds" => seconds}, socket) do
    seconds = String.to_integer(seconds)
    {:noreply, push_event(socket, "seek", %{seconds: seconds})}
  end

  @impl true
  def handle_event("delete_note", %{"id" => id}, socket) do
    note = Ash.get!(VideoNote, id)

    case Ash.destroy(note) do
      :ok ->
        {:noreply,
         socket
         |> load_notes()
         |> put_flash(:info, "Note deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete note")}
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

  defp parse_timestamp(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
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
    <div class="flex flex-col gap-4 mt-4">
      <div class="space-y-4">
        <%= for note <- @notes do %>
          <.card class="relative" color="base" variant="default">
            <.card_content>
              <div class="flex justify-between items-start gap-4">
                <div class="whitespace-pre-wrap flex-1">{note.body}</div>
                <div class="flex items-center gap-2">
                  <%= if note.video_timestamp do %>
                    <button
                      class="font-mono text-sm text-primary hover:underline whitespace-nowrap cursor-pointer"
                      phx-click="seek_video"
                      phx-target={@myself}
                      phx-value-seconds={note.video_timestamp}
                    >
                      {format_timestamp(note.video_timestamp)}
                    </button>
                  <% else %>
                    <div class="font-mono text-sm text-base-content/70 whitespace-nowrap">
                      {format_timestamp(note.video_timestamp)}
                    </div>
                  <% end %>
                  <button
                    phx-click="delete_note"
                    phx-target={@myself}
                    phx-value-id={note.id}
                    data-confirm="This note wll be permanently deleted.  Are you certain?"
                    class="p-1 text-error hover:bg-error/10 rounded-full transition-colors"
                    aria-label="Delete note"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </button>
                </div>
              </div>
            </.card_content>
          </.card>
        <% end %>
      </div>

      <div class="mt-2">
        <.button phx-click="add_note" phx-target={@myself} color="primary">
          <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Add Note
        </.button>
      </div>

      <Modal.modal
        :if={@show_modal}
        id="add-note-modal"
        show={@show_modal}
        title="Add New Note"
        on_cancel={JS.push("close_modal", target: @myself)}
      >
        <div class="p-1">
          <.form for={@form} phx-submit="save_note" phx-target={@myself} class="flex flex-col gap-4">
            <.input
              field={@form[:video_timestamp]}
              type="number"
              label="Timestamp (seconds)"
              placeholder="e.g. 65 for 1:05"
              value={@current_time}
            />

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
