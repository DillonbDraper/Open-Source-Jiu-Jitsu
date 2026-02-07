defmodule FosBjjWeb.UserProfileLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjj.Accounts.Academy
  alias FosBjj.Accounts.CoachApplication
  alias FosBjj.Accounts.User
  alias FosBjjWeb.AcademyLive.NewAcademyForm
  alias FosBjjWeb.CoachApplicationForm
  alias FosBjjWeb.VideoLive.VideoFormComponent
  alias FosBjjWeb.Components.MessagesTableComponent
  alias FosBjjWeb.Components.NotesTableComponent
  alias FosBjjWeb.Components.CoachesTableComponent
  alias FosBjjWeb.Components.FollowersTableComponent
  alias FosBjjWeb.Components.UserProfilePanel

  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Pagination
  import FosBjjWeb.Components.UserProfilePanel
  import FosBjjWeb.Components.Drawer

  require Ash.Query

  on_mount({AshAuthentication.Phoenix.LiveSession, {:live_user_required, otp_app: :fos_bjj}})

  @impl true
  def mount(_params, _session, socket) do
    user =
      socket.assigns.current_user
      |> Ash.load!([:academies], actor: socket.assigns.current_user)

    academies = list_academies(user)
    academy_options = Enum.map(academies, &{&1.name, to_string(&1.id)})
    selected_academy_ids = Enum.map(user.academies, &to_string(&1.id))
    profile_form = build_profile_form(user, selected_academy_ids)
    coach_application_status = coach_application_status(user)

    {:ok,
     socket
     |> assign(:page_title, "User Profile")
     |> assign(:current_user, user)
     |> assign(:show_videos, false)
     |> assign(:videos, [])
     |> assign(:video_to_edit, nil)
     |> assign(:show_edit_modal, false)
     |> assign(:video_search_query, "")
     |> assign(:current_page, 1)
     |> assign(:total_videos, 0)
     |> assign(:show_profile_modal, false)
     |> assign(:show_academy_drawer, false)
     |> assign(:profile_form, profile_form)
     |> assign(:academy_options, academy_options)
     |> assign(:selected_academy_ids, selected_academy_ids)
     |> assign(:academy_combobox_version, 0)
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
    if User.coach_application_eligible?(socket.assigns.current_user) do
      {:noreply, assign(socket, :show_coach_application_modal, true)}
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "Coach applications are limited to black belts or practitioners with other high level experience."
       )}
    end
  end

  @impl true
  def handle_event("open_profile_modal", _, socket) do
    socket =
      socket
      |> refresh_profile_form()
      |> assign(:show_profile_modal, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_profile_modal", _, socket) do
    {:noreply, assign(socket, :show_profile_modal, false)}
  end

  @impl true
  def handle_event("open_academy_drawer", _, socket) do
    {:noreply, assign(socket, :show_academy_drawer, true)}
  end

  @impl true
  def handle_event("close_academy_drawer", _, socket) do
    {:noreply, assign(socket, :show_academy_drawer, false)}
  end

  @impl true
  def handle_event("validate_profile", %{"profile" => params}, socket) do
    academy_ids =
      params
      |> Map.get("academy_ids", [])
      |> List.wrap()
      |> Enum.reject(&(&1 == ""))

    cleaned_params =
      params
      |> Map.put("academy_ids", academy_ids)
      |> Map.put("bjj_belt", normalize_blank(params["bjj_belt"]))

    form =
      AshPhoenix.Form.validate(socket.assigns.profile_form, cleaned_params,
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:profile_form, form)
     |> assign(:selected_academy_ids, academy_ids)}
  end

  @impl true
  def handle_event("save_profile", %{"profile" => params}, socket) do
    academy_ids =
      params
      |> Map.get("academy_ids", [])
      |> List.wrap()
      |> Enum.reject(&(&1 == ""))

    cleaned_params =
      params
      |> Map.put("academy_ids", academy_ids)
      |> Map.put("bjj_belt", normalize_blank(params["bjj_belt"]))

    case AshPhoenix.Form.submit(socket.assigns.profile_form,
           params: cleaned_params,
           actor: socket.assigns.current_user
         ) do
      {:ok, updated_user} ->
        updated_user = Ash.load!(updated_user, [:academies], actor: updated_user)
        academies = list_academies(updated_user)

        academy_options = Enum.map(academies, &{&1.name, to_string(&1.id)})
        selected_academy_ids = Enum.map(updated_user.academies, &to_string(&1.id))
        profile_form = build_profile_form(updated_user, selected_academy_ids)

        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:show_profile_modal, false)
         |> assign(:academy_options, academy_options)
         |> assign(:selected_academy_ids, selected_academy_ids)
         |> assign(:profile_form, profile_form)
         |> put_flash(:info, "Profile updated successfully")}

      {:error, form} ->
        {:noreply, assign(socket, :profile_form, form)}
    end
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
  def handle_info({NewAcademyForm, {:academy_created, academy}}, socket) do
    params = socket.assigns.profile_form.params || %{}

    academy_ids =
      params
      |> Map.get("academy_ids", socket.assigns.selected_academy_ids)
      |> List.wrap()
      |> Enum.reject(&(&1 == ""))

    updated_academy_ids =
      [to_string(academy.id) | academy_ids]
      |> Enum.uniq()

    academy_options =
      [{academy.name, to_string(academy.id)} | socket.assigns.academy_options]
      |> Enum.uniq_by(fn {_name, id} -> id end)
      |> Enum.sort_by(fn {name, _id} -> String.downcase(name) end)

    updated_params =
      params
      |> Map.put("academy_ids", updated_academy_ids)
      |> Map.put("bjj_belt", normalize_blank(params["bjj_belt"]))

    form =
      AshPhoenix.Form.validate(socket.assigns.profile_form, updated_params,
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:academy_options, academy_options)
     |> assign(:selected_academy_ids, updated_academy_ids)
     |> assign(:profile_form, form)
     |> assign(:show_academy_drawer, false)
     |> assign(:academy_combobox_version, socket.assigns.academy_combobox_version + 1)
     |> put_flash(:info, "Academy created successfully")}
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

  defp list_academies(user) do
    Academy
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(actor: user)
  end

  defp build_profile_form(user, academy_ids) do
    user
    |> AshPhoenix.Form.for_update(:update_profile, as: "profile", actor: user)
    |> AshPhoenix.Form.validate(%{"academy_ids" => academy_ids}, actor: user)
    |> to_form()
  end

  defp refresh_profile_form(socket) do
    user =
      socket.assigns.current_user
      |> Ash.load!([:academies], actor: socket.assigns.current_user)

    academies = list_academies(user)
    academy_options = Enum.map(academies, &{&1.name, to_string(&1.id)})
    selected_academy_ids = Enum.map(user.academies, &to_string(&1.id))
    profile_form = build_profile_form(user, selected_academy_ids)

    socket
    |> assign(:current_user, user)
    |> assign(:academy_options, academy_options)
    |> assign(:selected_academy_ids, selected_academy_ids)
    |> assign(:profile_form, profile_form)
  end

  defp normalize_blank(nil), do: nil
  defp normalize_blank(""), do: nil
  defp normalize_blank(value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_width current_user={assigns[:current_user]} socket={@socket}>
      <div class="space-y-8">
        <.user_profile_panel
          current_user={@current_user}
          coach_application_status={@coach_application_status}
        />

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

          <.live_component
            module={CoachesTableComponent}
            id="coaches-table"
            current_user={@current_user}
          />
        <% end %>

        <%= if @current_user.role_name in ["coach", "admin"] do %>
          <.live_component
            module={FollowersTableComponent}
            id="followers-table"
            current_user={@current_user}
          />

          <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
            <.h3 size="text-lg" font_weight="font-medium" class="mb-4">
              Coach Options
            </.h3>
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
            <.h3 size="text-lg" font_weight="font-medium" class="mb-4">
              Admin Options
            </.h3>
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

      <%!-- Profile Modal - rendered at LiveView level to prevent unmounting when drawer opens --%>
      <.modal
        :if={@show_profile_modal}
        show
        id="profile-modal"
        size="large"
        close_on_click_away={!@show_academy_drawer}
        close_on_escape={!@show_academy_drawer}
        on_cancel={JS.push("close_profile_modal")}
      >
        <div class="space-y-6">
          <div>
            <.h3 class="text-2xl font-semibold text-base-content">
              Update Profile Details
            </.h3>
          </div>

          <.form
            for={@profile_form}
            id="user-profile-form"
            phx-change="validate_profile"
            phx-submit="save_profile"
          >
            <div class="grid gap-4">
              <.input
                type="select"
                field={@profile_form[:bjj_belt]}
                label="BJJ Belt"
                prompt="Select your belt"
                options={UserProfilePanel.belt_options()}
              />

              <.input
                type="checkbox"
                field={@profile_form[:other_high_level_experience]}
                label="Other high level experience (wrestling, judo, sambo, etc.)"
              />

              <div>
                <.combobox
                  id={"academy-select-#{@academy_combobox_version}"}
                  field={@profile_form[:academy_ids]}
                  label="Academies"
                  value={@selected_academy_ids}
                  placeholder="Search academies..."
                  searchable={true}
                  multiple={true}
                  size="extra_large"
                >
                  <:option :for={{name, id} <- @academy_options} value={id}>
                    {name}
                  </:option>
                </.combobox>
                <div class="mt-2 flex flex-wrap items-center gap-3">
                  <.p size="text-xs" class="text-base-content/60">
                    Search and select multiple academies.
                  </.p>
                  <.button
                    id="open-academy-drawer"
                    type="button"
                    class="btn btn-outline btn-xs"
                    phx-click="open_academy_drawer"
                  >
                    Add an academy
                  </.button>
                </div>
              </div>
            </div>

            <div class="mt-6 flex flex-wrap justify-end gap-3">
              <.button
                id="cancel-profile-edit"
                type="button"
                class="btn btn-ghost"
                phx-click="close_profile_modal"
              >
                Cancel
              </.button>
              <.button id="save-profile" type="submit" class="btn btn-primary">
                Save Profile
              </.button>
            </div>
          </.form>
        </div>
      </.modal>

      <%!-- Academy Drawer - rendered at LiveView level to prevent modal unmounting --%>
      <.drawer
        :if={@show_academy_drawer}
        id="academy-drawer"
        show={@show_academy_drawer}
        on_hide={
          JS.push("close_academy_drawer")
          |> hide_drawer("academy-drawer", "right")
        }
        on_hide_away={
          JS.push("close_academy_drawer")
          |> hide_drawer("academy-drawer", "right")
        }
        position="right"
      >
        <.live_component
          :if={@show_academy_drawer}
          module={NewAcademyForm}
          id="new-academy-form"
          current_user={@current_user}
        />
      </.drawer>
    </Layouts.app>
    """
  end
end
