defmodule FosBjjWeb.UserProfileLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjj.JiuJitsu.VideoNote
  alias FosBjjWeb.VideoLive.VideoFormComponent
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  require Ash.Query

  on_mount({AshAuthentication.Phoenix.LiveSession, {:live_user_required, otp_app: :fos_bjj}})

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    notes = list_user_notes(user, "", 1)

    {:ok,
     socket
     |> assign(:page_title, "User Profile")
     |> assign(:show_videos, false)
     |> assign(:videos, [])
     |> assign(:video_to_edit, nil)
     |> assign(:show_edit_modal, false)
     |> assign(:video_search_query, "")
     |> assign(:current_page, 1)
     |> assign(:total_videos, 0)
     |> assign(:notes, notes)
     |> assign(:notes_page, 1)
     |> assign(:notes_search_query, "")}
  end

  @impl true
  def handle_event("search_notes", %{"query" => query}, socket) do
    page = 1
    notes = list_user_notes(socket.assigns.current_user, query, page)

    {:noreply,
     assign(socket,
       notes_search_query: query,
       notes: notes,
       notes_page: page
     )}
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
      list_user_notes(socket.assigns.current_user, socket.assigns.notes_search_query, page)

    {:noreply,
     socket
     |> assign(:notes, notes)
     |> assign(:notes_page, page)}
  end

  @impl true
  def handle_event("toggle_videos", _, socket) do
    if socket.assigns.show_videos do
      {:noreply, assign(socket, :show_videos, false)}
    else
      page = 1

      videos =
        list_user_videos(socket.assigns.current_user, socket.assigns.video_search_query, page)

      {:noreply,
       socket
       |> assign(:show_videos, true)
       |> assign(:videos, videos)
       |> assign(:current_page, page)
       |> assign(:total_videos, videos.count)}
    end
  end

  @impl true
  def handle_event("search_videos", %{"query" => query}, socket) do
    page = 1
    videos = list_user_videos(socket.assigns.current_user, query, page)

    {:noreply,
     assign(socket,
       video_search_query: query,
       videos: videos,
       current_page: page,
       total_videos: videos.count
     )}
  end

  @impl true
  def handle_event("pagination", params, socket) do
    current_page = socket.assigns.current_page || 1

    total_pages =
      if socket.assigns[:total_videos], do: ceil(socket.assigns.total_videos / 10), else: 1

    page =
      case params["action"] do
        "select" -> params["page"]
        "next" -> min(current_page + 1, total_pages)
        "previous" -> max(current_page - 1, 1)
        "first" -> 1
        "last" -> total_pages
        _ -> params["page"] || current_page
      end

    videos =
      list_user_videos(socket.assigns.current_user, socket.assigns.video_search_query, page)

    {:noreply,
     socket
     |> assign(:videos, videos)
     |> assign(:current_page, page)
     |> assign(:total_videos, videos.count)}
  end

  @impl true
  def handle_event("edit_video", %{"id" => id}, socket) do
    video = Ash.get!(Video, id, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:video_to_edit, video)
     |> assign(:show_edit_modal, true)}
  end

  @impl true
  def handle_event("close_edit_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:video_to_edit, nil)
     |> assign(:show_edit_modal, false)}
  end

  @impl true
  def handle_event("delete_video", %{"id" => id}, socket) do
    if socket.assigns.current_user.role_name == "admin" do
      Video
      |> Ash.get!(id, actor: socket.assigns.current_user)
      |> Ash.destroy!(actor: socket.assigns.current_user)

      page = socket.assigns.current_page
      user = socket.assigns.current_user
      query = socket.assigns.video_search_query

      videos = list_user_videos(user, query, page)

      {videos, page} =
        if videos.results == [] && page > 1 do
          new_page = page - 1
          {list_user_videos(user, query, new_page), new_page}
        else
          {videos, page}
        end

      {:noreply, assign(socket, videos: videos, total_videos: videos.count, current_page: page)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_info({:video_saved, _video}, socket) do
    page = socket.assigns.current_page
    user = socket.assigns.current_user
    query = socket.assigns.video_search_query

    videos = list_user_videos(user, query, page)

    {videos, page} =
      if videos.results == [] && page > 1 do
        new_page = page - 1
        {list_user_videos(user, query, new_page), new_page}
      else
        {videos, page}
      end

    {:noreply,
     socket
     |> assign(:videos, videos)
     |> assign(:current_page, page)
     |> assign(:total_videos, videos.count)
     |> assign(:show_edit_modal, false)
     |> assign(:video_to_edit, nil)
     |> put_flash(:info, "Video updated successfully")}
  end

  defp list_user_notes(user, query, page) do
    offset = (page - 1) * 10

    VideoNote
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.load(:video)
    |> then(fn q ->
      if query != "" do
        query_string = "%#{query}%"

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

  defp format_timestamp(nil), do: "--:--"

  defp format_timestamp(seconds) when is_integer(seconds) do
    min = div(seconds, 60)
    sec = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [min, sec]) |> to_string()
  end

  defp format_timestamp(_), do: "--:--"

  defp list_user_videos(user, query, page) do
    offset = (page - 1) * 5

    Video
    |> Ash.Query.filter(created_by.id == ^user.id)
    |> then(fn q ->
      if query != "" do
        Ash.Query.filter(q, contains(title, ^query))
      else
        q
      end
    end)
    |> Ash.Query.load([:techniques, :grips])
    |> Ash.read!(actor: user, page: [limit: 5, offset: offset, count: true])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_width current_user={assigns[:current_user]}>
      <div class="space-y-8">
        <header>
          <.h1 class="text-3xl font-extrabold tracking-tight text-base-content">
            Hey there!
          </.h1>
          <p class="mt-2 text-lg text-base-content/70">
            Here's your profile and settings.
          </p>
        </header>

        <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
          <.h3 class="text-lg font-medium mb-4">My Notes</.h3>
          <div class="mb-4">
            <form phx-change="search_notes" phx-submit="search_notes">
              <.search_field
                name="query"
                value={@notes_search_query}
                placeholder="Search notes by note or video title..."
                phx-change="search_notes"
                phx-debounce="400"
              />
            </form>
          </div>

          <.table padding="extra_small" border="medium" rows={@notes.results}>
            <:col :let={note} label="Video">
              <.link navigate={~p"/videos/#{note.video_id}"} class="link link-primary font-semibold">
                {note.video.title}
              </.link>
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
              <.link
                navigate={~p"/videos/#{note.video_id}?time=#{note.video_timestamp}"}
                class="link link-primary font-semibold text-blue-600"
              >
                {format_timestamp(note.video_timestamp)}
              </.link>
            </:col>
            <:col :let={note} label="Created">
              {Calendar.strftime(note.inserted_at, "%b %d, %Y %H:%M %p")}
            </:col>
          </.table>

          <%= if @notes.count > 10 do %>
            <div class="mt-4 flex justify-center">
              <.pagination
                total={ceil(@notes.count / 10)}
                active={@notes_page}
                siblings={1}
                phx-click="notes_pagination"
              />
            </div>
          <% end %>
        </div>

        <%= if @current_user.role_name in ["coach", "admin"] do %>
          <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
            <h3 class="text-lg font-medium mb-4">Coach Options</h3>
            <div>
              <.button phx-click="toggle_videos" class="btn-primary">
                {if @show_videos, do: "Hide My Videos", else: "Show My Videos"}
              </.button>
            </div>

            <%= if @show_videos do %>
              <div class="mt-6">
                <div class="mb-4">
                  <form phx-change="search_videos" phx-submit="search_videos">
                    <.search_field
                      name="query"
                      value={@video_search_query}
                      placeholder="Search videos by title..."
                      phx-change="search_videos"
                      phx-debounce="400"
                    />
                  </form>
                </div>
                <.table padding="extra_small" border="medium" rows={@videos.results}>
                  <:col :let={video} label="Thumbnail">
                    <.image height={250} width={200} src={video.thumbnail_url} />
                  </:col>
                  <:col :let={video} label="Title">{video.title}</:col>
                  <:col :let={video} label="Techniques">
                    {Enum.map(video.techniques, & &1.name) |> Enum.join(", ")}
                  </:col>
                  <:col :let={video} label="Grips">
                    {Enum.map(video.grips, & &1.label) |> Enum.join(", ")}
                  </:col>
                  <:action :let={video}>
                    <div class="flex gap-2">
                      <.button
                        phx-click="edit_video"
                        phx-value-id={video.id}
                        class="btn btn-sm btn-ghost"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.button>
                      <%= if @current_user.role_name == "admin" do %>
                        <.button
                          phx-click="delete_video"
                          phx-value-id={video.id}
                          data-confirm="Are you sure?"
                          class="btn btn-sm btn-ghost text-error"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </.button>
                      <% end %>
                    </div>
                  </:action>
                </.table>

                <%= if @total_videos > 5 do %>
                  <div class="mt-4 flex justify-center">
                    <.pagination
                      total={ceil(@total_videos / 5)}
                      active={@current_page}
                      siblings={1}
                    />
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @current_user.role_name == "admin" do %>
          <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
            <h3 class="text-lg font-medium mb-4">Admin Options</h3>
            <div>
              <.link navigate={~p"/admin/users"} class="btn btn-secondary">
                Manage Users
              </.link>
            </div>
          </div>
        <% end %>

        <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
          <.h3 class="text-lg font-medium mb-4">Theme Settings</.h3>
          <div class="flex flex-wrap gap-4">
            <.button
              class="btn btn-outline"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme="light"
            >
              <.icon name="hero-sun" class="w-5 h-5 mr-2" /> Light
            </.button>
            <.button
              class="btn btn-outline"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme="dark"
            >
              <.icon name="hero-moon" class="w-5 h-5 mr-2" /> Dark
            </.button>
          </div>
        </div>

        <.modal
          :if={@show_edit_modal}
          show
          id="edit-video-modal"
          size="triple_large"
          on_cancel={JS.push("close_edit_modal")}
        >
          <.live_component
            module={VideoFormComponent}
            id="edit-video-form"
            video={@video_to_edit}
            current_user={@current_user}
            action={:update}
            on_cancel={JS.exec("data-cancel", to: "#edit-video-modal")}
          />
        </.modal>
      </div>
    </Layouts.app>
    """
  end
end
