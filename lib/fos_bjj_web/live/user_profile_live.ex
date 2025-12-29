defmodule FosBjjWeb.UserProfileLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjjWeb.VideoLive.VideoFormComponent
  import FosBjjWeb.Components.SearchField
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
     |> assign(:video_search_query, "")}
  end

  @impl true
  def handle_event("toggle_videos", _, socket) do
    if socket.assigns.show_videos do
      {:noreply, assign(socket, :show_videos, false)}
    else
      videos = list_user_videos(socket.assigns.current_user, socket.assigns.video_search_query)

      {:noreply,
       socket
       |> assign(:show_videos, true)
       |> assign(:videos, videos)}
    end
  end

  @impl true
  def handle_event("search_videos", %{"query" => query}, socket) do
    videos = list_user_videos(socket.assigns.current_user, query)
    {:noreply, assign(socket, video_search_query: query, videos: videos)}
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

      videos = list_user_videos(socket.assigns.current_user, socket.assigns.video_search_query)

      {:noreply, assign(socket, :videos, videos)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_info({:video_saved, _video}, socket) do
    videos = list_user_videos(socket.assigns.current_user, socket.assigns.video_search_query)

    {:noreply,
     socket
     |> assign(:videos, videos)
     |> assign(:show_edit_modal, false)
     |> assign(:video_to_edit, nil)
     |> put_flash(:info, "Video updated successfully")}
  end

  defp list_user_videos(user, query) do
    IO.inspect(query)

    Video
    |> Ash.Query.filter(created_by.id == ^user.id)
    |> then(fn q ->
      if query != "" do
        Ash.Query.filter(q, contains(title, ^query))
      else
        q
      end
    end)
    |> Ash.read!(actor: user, page: [limit: 20])
    |> Ash.load!([:techniques, :grips])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <.h1 class="text-2xl font-bold">{@page_title}</.h1>
        <.p class="text-gray-600">Manage your account settings and preferences.</.p>
      </div>

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
                <:action :let={video} label="Action(s)">
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
    """
  end
end
