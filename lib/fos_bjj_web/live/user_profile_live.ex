defmodule FosBjjWeb.UserProfileLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjj.Accounts.CoachApplication
  alias FosBjjWeb.CoachApplicationForm
  alias FosBjjWeb.VideoLive.VideoFormComponent
  alias FosBjjWeb.Components.MessagesTableComponent
  alias FosBjjWeb.Components.NotesTableComponent
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  require Ash.Query

  on_mount({AshAuthentication.Phoenix.LiveSession, {:live_user_required, otp_app: :fos_bjj}})

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    coach_application_status = coach_application_status(user)

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
     |> assign(:show_coach_application_modal, false)
     |> assign(:coach_application_status, coach_application_status)}
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
          new_page = 1
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
  def handle_event("open_coach_application_modal", _, socket) do
    {:noreply, assign(socket, :show_coach_application_modal, true)}
  end

  @impl true
  def handle_info({:coach_application_closed}, socket) do
    {:noreply, assign(socket, :show_coach_application_modal, false)}
  end

  @impl true
  def handle_info({:coach_application_submitted, {:ok, _}}, socket) do
    {:noreply,
     socket
     |> assign(:show_coach_application_modal, false)
     |> assign(:coach_application_status, :pending)
     |> put_flash(:info, "Coach application submitted successfully.")}
  end

  @impl true
  def handle_info({:coach_application_submitted, {:error, :missing_recipient}}, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Coach application recipient is not configured. Please contact support."
     )}
  end

  @impl true
  def handle_info({:coach_application_submitted, {:error, _}}, socket) do
    {:noreply, put_flash(socket, :error, "Failed to deliver coach application email.")}
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

  defp coach_application_status(user) do
    has_denied? =
      CoachApplication
      |> Ash.Query.filter(user_id == ^user.id and status == :denied)
      |> Ash.read!(actor: user)
      |> Enum.any?()

    cond do
      has_denied? ->
        :denied

      coach_application_pending?(user) ->
        :pending

      true ->
        :none
    end
  end

  defp coach_application_pending?(user) do
    CoachApplication
    |> Ash.Query.filter(user_id == ^user.id and status == :pending)
    |> Ash.read!(actor: user)
    |> Enum.any?()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_width current_user={assigns[:current_user]}>
      <div class="space-y-8">
        <header class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <.h1 class="text-3xl font-extrabold tracking-tight text-base-content">
              Hey there!
            </.h1>
            <p class="mt-2 text-lg text-base-content/70">
              Here's your profile and settings.
            </p>
          </div>

          <%= if @current_user.role_name == "student" && @coach_application_status != :denied do %>
            <div class="flex items-center gap-3">
              <%= if @coach_application_status == :pending do %>
                <div class="flex items-center gap-2">
                  <.tooltip
                    id="coach-application-processing-tooltip"
                    inline={true}
                    position="bottom"
                    width="triple_large"
                    trigger_class="inline-flex"
                    content_class="max-w-xs whitespace-normal text-sm"
                  >
                    <:trigger>
                      <span class="inline-flex cursor-help">
                        <.icon
                          name="hero-information-circle"
                          class="size-5 text-base-content/70"
                        />
                      </span>
                    </:trigger>
                    <:content>
                      Your application to become a coach and gain the ability to upload videos, share with your students, and more is
                      being processed. Thank you for your interest in contributing to OSSBJJ!
                    </:content>
                  </.tooltip>
                  <.button
                    id="coach-application-processing"
                    class="btn btn-primary"
                    disabled
                  >
                    Application processing...
                  </.button>
                </div>
              <% else %>
                <.button
                  id="open-coach-application"
                  phx-click="open_coach_application_modal"
                  class="btn btn-primary"
                >
                  Become A Coach
                </.button>
              <% end %>
            </div>
          <% end %>
        </header>

        <%= if FosBjj.Accounts.User.verified?(@current_user) do %>
          <.live_component
            module={NotesTableComponent}
            id="notes-table"
            current_user={@current_user}
          />

          <.live_component
            module={MessagesTableComponent}
            id="messages-table"
            current_user={@current_user}
          />
        <% end %>

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

        <.live_component
          module={CoachApplicationForm}
          id="coach-application-form"
          current_user={@current_user}
          show={@show_coach_application_modal}
        />
      </div>
    </Layouts.app>
    """
  end
end
