defmodule FosBjjWeb.UserProfileLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjjWeb.VideoLive.VideoFormComponent
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "User Profile")
     |> assign(:show_videos, false)
     |> assign(:videos, [])
     |> assign(:video_to_edit, nil)
     |> assign(:show_edit_modal, false)
     |> assign(:video_search_query, "")
     |> assign(:current_page, 1)
     |> assign(:total_videos, 0)}
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
          <h1 class="text-3xl font-extrabold tracking-tight text-base-content">
            {@page_title}
          </h1>
          <p class="mt-2 text-lg text-base-content/70">
            Manage your account settings and preferences.
          </p>
        </header>

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
