defmodule FosBjjWeb.UserProfileLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjj.Accounts.Academy
  alias FosBjj.Accounts.AcademyUser
  alias FosBjj.Accounts.ContributorApplication
  alias FosBjj.Accounts.User
  alias FosBjjWeb.AcademyLive.NewAcademyForm
  alias FosBjjWeb.ContributorApplicationForm
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

    {selected_academy_ids, academy_lookup, primary_academy_id, academy_memberships} =
      get_user_academy_state(user)

    profile_form = build_profile_form(user, selected_academy_ids, %{})
    contributor_application_status = contributor_application_status(user)

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
     |> assign(:selected_academy_ids, selected_academy_ids)
     |> assign(:academy_lookup, academy_lookup)
     |> assign(:primary_academy_id, primary_academy_id)
     |> assign(:academy_memberships, academy_memberships)
     |> assign(:show_academy_search, false)
     |> assign(:academy_search_query, "")
     |> assign(:academy_search_results, [])
     |> assign(:show_contributor_application_modal, false)
     |> assign(:contributor_application_status, contributor_application_status)}
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
  def handle_event("open_contributor_application_modal", _, socket) do
    if User.contributor_application_eligible?(socket.assigns.current_user) do
      {:noreply, assign(socket, :show_contributor_application_modal, true)}
    else
      # Questionable if actually necessary as condition should never be hit
      {:noreply,
       put_flash(
         socket,
         :error,
         "Contributor applications are limited to black belts or practitioners with other high level experience."
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
  def handle_event("close_academy_selector", _, socket) do
    {:noreply,
     socket
     |> assign(:show_academy_search, false)
     |> assign(:academy_search_query, "")
     |> assign(:academy_search_results, [])}
  end

  @impl true
  def handle_event("open_academy_selector", _, socket) do
    {:noreply,
     socket
     |> assign(:show_academy_search, true)
     |> assign(:academy_search_query, "")
     |> assign(:academy_search_results, [])}
  end

  @impl true
  def handle_event("search_academies", params, socket) do
    query = params["query"] || params["value"] || ""

    results =
      search_academies(
        socket.assigns.current_user,
        query,
        socket.assigns.selected_academy_ids
      )

    {:noreply,
     socket
     |> assign(:academy_search_query, query)
     |> assign(:academy_search_results, results)}
  end

  @impl true
  def handle_event("select_academy", %{"id" => id}, socket) do
    academy_id = String.to_integer(id)
    selected_ids = socket.assigns.selected_academy_ids

    if academy_id in selected_ids do
      {:noreply, socket}
    else
      academy =
        Enum.find(socket.assigns.academy_search_results, &(&1.id == academy_id)) ||
          Ash.get!(Academy, academy_id, actor: socket.assigns.current_user)

      updated_ids = [academy_id | selected_ids]
      updated_primary_id = socket.assigns.primary_academy_id || academy_id
      updated_lookup = Map.put(socket.assigns.academy_lookup, academy_id, academy)

      form =
        build_profile_form(
          socket.assigns.current_user,
          updated_ids,
          socket.assigns.profile_form.params || %{}
        )

      {:noreply,
       socket
       |> assign(:selected_academy_ids, updated_ids)
       |> assign(:academy_lookup, updated_lookup)
       |> assign(:primary_academy_id, updated_primary_id)
       |> assign(:show_academy_search, false)
       |> assign(:academy_search_query, "")
       |> assign(:academy_search_results, [])
       |> assign(:profile_form, form)}
    end
  end

  @impl true
  def handle_event("remove_academy", %{"id" => id}, socket) do
    academy_id = String.to_integer(id)
    selected_ids = socket.assigns.selected_academy_ids

    updated_ids = Enum.reject(selected_ids, &(&1 == academy_id))

    updated_primary_id =
      if socket.assigns.primary_academy_id == academy_id do
        List.first(updated_ids)
      else
        socket.assigns.primary_academy_id
      end

    updated_lookup = Map.delete(socket.assigns.academy_lookup, academy_id)

    form =
      build_profile_form(
        socket.assigns.current_user,
        updated_ids,
        socket.assigns.profile_form.params || %{}
      )

    {:noreply,
     socket
     |> assign(:selected_academy_ids, updated_ids)
     |> assign(:academy_lookup, updated_lookup)
     |> assign(:primary_academy_id, updated_primary_id)
     |> assign(:profile_form, form)}
  end

  @impl true
  def handle_event("set_primary_academy", %{"id" => id}, socket) do
    academy_id = String.to_integer(id)

    if academy_id in socket.assigns.selected_academy_ids do
      {:noreply, assign(socket, :primary_academy_id, academy_id)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_profile", %{"profile" => params}, socket) do
    academy_ids = socket.assigns.selected_academy_ids

    cleaned_params =
      params
      |> Map.put("academy_ids", academy_ids)
      |> Map.put("bjj_belt", normalize_blank(params["bjj_belt"]))
      |> Map.put("role", params["role"] || socket.assigns.current_user.role_name)

    form =
      AshPhoenix.Form.validate(socket.assigns.profile_form, cleaned_params,
        actor: socket.assigns.current_user
      )

    {:noreply, assign(socket, :profile_form, form)}
  end

  @impl true
  def handle_event("save_profile", %{"profile" => params}, socket) do
    academy_ids = socket.assigns.selected_academy_ids
    primary_academy_id = ensure_primary_id(academy_ids, socket.assigns.primary_academy_id)

    cleaned_params =
      params
      |> Map.put("academy_ids", academy_ids)
      |> Map.put("bjj_belt", normalize_blank(params["bjj_belt"]))
      |> Map.put("role", params["role"] || socket.assigns.current_user.role_name)

    case AshPhoenix.Form.submit(socket.assigns.profile_form,
           params: cleaned_params,
           actor: socket.assigns.current_user
         ) do
      {:ok, updated_user} ->
        _ = persist_primary_academy(updated_user, primary_academy_id)
        updated_user = Ash.load!(updated_user, [:academies], actor: updated_user)

        {selected_academy_ids, academy_lookup, updated_primary_academy_id, academy_memberships} =
          get_user_academy_state(updated_user)

        profile_form = build_profile_form(updated_user, selected_academy_ids, %{})

        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:show_profile_modal, false)
         |> assign(:selected_academy_ids, selected_academy_ids)
         |> assign(:academy_lookup, academy_lookup)
         |> assign(:primary_academy_id, updated_primary_academy_id)
         |> assign(:academy_memberships, academy_memberships)
         |> assign(:show_academy_search, false)
         |> assign(:academy_search_query, "")
         |> assign(:academy_search_results, [])
         |> assign(:profile_form, profile_form)
         |> put_flash(:info, "Profile updated successfully")}

      {:error, form} ->
        {:noreply, assign(socket, :profile_form, form)}
    end
  end

  @impl true
  def handle_info({:contributor_application_closed}, socket) do
    {:noreply, assign(socket, :show_contributor_application_modal, false)}
  end

  @impl true
  def handle_info({:contributor_application_submitted, {:ok, _}}, socket) do
    {:noreply,
     socket
     |> assign(:show_contributor_application_modal, false)
     |> assign(:contributor_application_status, :pending)
     |> put_flash(:info, "Contributor application submitted successfully.")}
  end

  @impl true
  def handle_info({:contributor_application_submitted, {:error, :missing_recipient}}, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Contributor application recipient is not configured. Please contact support."
     )}
  end

  @impl true
  def handle_info({:contributor_application_submitted, {:error, _}}, socket) do
    {:noreply, put_flash(socket, :error, "Failed to deliver contributor application email.")}
  end

  @impl true
  def handle_info({NewAcademyForm, {:academy_created, academy}}, socket) do
    params = socket.assigns.profile_form.params || %{}
    updated_academy_ids = [academy.id | socket.assigns.selected_academy_ids]
    updated_primary_id = socket.assigns.primary_academy_id || academy.id
    updated_lookup = Map.put(socket.assigns.academy_lookup, academy.id, academy)

    form =
      build_profile_form(
        socket.assigns.current_user,
        updated_academy_ids,
        Map.put(params, "bjj_belt", normalize_blank(params["bjj_belt"]))
      )

    {:noreply,
     socket
     |> assign(:selected_academy_ids, updated_academy_ids)
     |> assign(:academy_lookup, updated_lookup)
     |> assign(:primary_academy_id, updated_primary_id)
     |> assign(:profile_form, form)
     |> assign(:show_academy_drawer, false)
     |> assign(:show_academy_search, false)
     |> assign(:academy_search_query, "")
     |> assign(:academy_search_results, [])
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

  defp contributor_application_status(user) do
    has_denied? =
      ContributorApplication
      |> Ash.Query.filter(user_id == ^user.id and status == :denied)
      |> Ash.read!(actor: user)
      |> Enum.any?()

    cond do
      has_denied? ->
        :denied

      contributor_application_pending?(user) ->
        :pending

      true ->
        :none
    end
  end

  defp contributor_application_pending?(user) do
    ContributorApplication
    |> Ash.Query.filter(user_id == ^user.id and status == :pending)
    |> Ash.read!(actor: user)
    |> Enum.any?()
  end

  defp list_user_academy_memberships(user) do
    AcademyUser
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.load(:academy)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(actor: user)
  end

  defp get_user_academy_state(user) do
    memberships = list_user_academy_memberships(user)
    selected_academy_ids = Enum.map(memberships, & &1.academy_id)

    academy_lookup =
      Enum.reduce(memberships, %{}, fn membership, acc ->
        Map.put(acc, membership.academy_id, membership.academy)
      end)

    primary_academy_id =
      memberships
      |> Enum.find(& &1.primary)
      |> case do
        %{academy_id: academy_id} -> academy_id
        _ -> List.first(selected_academy_ids)
      end

    ordered_memberships = order_memberships_by_primary(memberships, primary_academy_id)
    ordered_academy_ids = Enum.map(ordered_memberships, & &1.academy_id)

    {ordered_academy_ids, academy_lookup, primary_academy_id, ordered_memberships}
  end

  defp order_memberships_by_primary(memberships, nil), do: memberships

  defp order_memberships_by_primary(memberships, primary_id) do
    {primary, rest} =
      Enum.split_with(memberships, fn membership -> membership.academy_id == primary_id end)

    primary ++ rest
  end

  defp build_profile_form(user, academy_ids, params) do
    form_params =
      params
      |> Map.put_new("role", user.role_name)
      |> Map.put("academy_ids", academy_ids)

    user
    |> AshPhoenix.Form.for_update(:update_profile, as: "profile", actor: user)
    |> AshPhoenix.Form.validate(form_params, actor: user)
    |> to_form()
  end

  defp refresh_profile_form(socket) do
    user =
      socket.assigns.current_user
      |> Ash.load!([:academies], actor: socket.assigns.current_user)

    {selected_academy_ids, academy_lookup, primary_academy_id, academy_memberships} =
      get_user_academy_state(user)

    profile_form = build_profile_form(user, selected_academy_ids, %{})

    socket
    |> assign(:current_user, user)
    |> assign(:selected_academy_ids, selected_academy_ids)
    |> assign(:academy_lookup, academy_lookup)
    |> assign(:primary_academy_id, primary_academy_id)
    |> assign(:academy_memberships, academy_memberships)
    |> assign(:show_academy_search, false)
    |> assign(:academy_search_query, "")
    |> assign(:academy_search_results, [])
    |> assign(:profile_form, profile_form)
  end

  defp search_academies(user, query, excluded_ids) do
    Academy
    |> maybe_apply_academy_query(query)
    |> maybe_exclude_academies(excluded_ids)
    |> Ash.Query.sort(name: :asc)
    |> Ash.Query.limit(10)
    |> Ash.read!(actor: user)
  end

  defp maybe_apply_academy_query(ash_query, ""), do: ash_query

  defp maybe_apply_academy_query(ash_query, term) do
    query_string = "%#{term}%"

    Ash.Query.filter(
      ash_query,
      ilike(name, ^query_string) or
        ilike(address_line_1, ^query_string) or
        ilike(address_line_2, ^query_string) or
        ilike(city, ^query_string) or
        ilike(state, ^query_string) or
        ilike(zip, ^query_string) or
        ilike(country, ^query_string)
    )
  end

  defp maybe_exclude_academies(ash_query, []), do: ash_query

  defp maybe_exclude_academies(ash_query, ids) do
    Ash.Query.filter(ash_query, id not in ^ids)
  end

  defp academy_location(academy) do
    city = normalize_blank(academy.city)
    state = normalize_blank(academy.state)
    zip = normalize_blank(academy.zip)

    cond do
      city && state && zip -> "#{city}, #{state} #{zip}"
      city && state -> "#{city}, #{state}"
      city && zip -> "#{city} #{zip}"
      state && zip -> "#{state} #{zip}"
      city -> city
      state -> state
      zip -> zip
      true -> nil
    end
  end

  defp ensure_primary_id([], _primary_id), do: nil

  defp ensure_primary_id(academy_ids, nil), do: List.first(academy_ids)

  defp ensure_primary_id(academy_ids, primary_id) do
    if primary_id in academy_ids, do: primary_id, else: List.first(academy_ids)
  end

  defp persist_primary_academy(_user, nil), do: :ok

  defp persist_primary_academy(user, primary_id) do
    list_user_academy_memberships(user)
    |> Enum.each(fn membership ->
      desired = membership.academy_id == primary_id

      if membership.primary != desired do
        membership
        |> Ash.Changeset.for_update(:set_primary, %{primary: desired}, actor: user)
        |> Ash.update!()
      end
    end)
  end

  defp normalize_blank(nil), do: nil
  defp normalize_blank(""), do: nil
  defp normalize_blank(value), do: value

  defp role_options do
    [
      {"Student", "student"},
      {"Coach", "coach"}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_width current_user={assigns[:current_user]} socket={@socket}>
      <div class="space-y-8">
        <%= if @current_user.role_name in ["student", "coach"] &&
              @contributor_application_status != :denied &&
              User.contributor_application_eligible?(@current_user) do %>
          <div class="flex flex-wrap items-center justify-end gap-3">
            <%= if @contributor_application_status == :pending do %>
              <.tooltip
                id="contributor-application-processing-tooltip"
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
                  Your application to become a contributor and gain the ability to upload videos, share with your students, and more is
                  being processed. Thank you for your interest in contributing to OSSBJJ!
                </:content>
              </.tooltip>
              <.button
                id="contributor-application-processing"
                class="btn btn-primary"
                disabled
              >
                Application processing...
              </.button>
            <% else %>
              <.button
                id="open-contributor-application"
                phx-click="open_contributor_application_modal"
                class="btn btn-primary"
              >
                Apply To Become A Contributor
              </.button>
            <% end %>
          </div>
        <% end %>

        <.user_profile_panel
          current_user={@current_user}
          academy_memberships={@academy_memberships}
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

        <%= if @current_user.role_name in ["coach", "contributor", "admin"] do %>
          <.live_component
            module={FollowersTableComponent}
            id="followers-table"
            current_user={@current_user}
          />
        <% end %>

        <%= if @current_user.role_name in ["contributor", "admin"] do %>
          <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
            <.h3 size="text-lg" font_weight="font-medium" class="mb-4">
              Contributor Options
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
          module={ContributorApplicationForm}
          id="contributor-application-form"
          current_user={@current_user}
          show={@show_contributor_application_modal}
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
                type="select"
                field={@profile_form[:role]}
                label="Role"
                options={role_options()}
              />

              <.input
                type="checkbox"
                field={@profile_form[:other_high_level_experience]}
                label="Other high level experience (wrestling, judo, sambo, etc.)"
              />

              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <.p size="text-sm" font_weight="font-semibold" class="text-base-content">
                    Academies
                  </.p>
                  <.button
                    id="open-academy-selector"
                    type="button"
                    class="btn btn-ghost btn-xs"
                    phx-click="open_academy_selector"
                    aria-label="Search academies"
                    title="Add an Academy"
                  >
                    <.icon name="hero-plus" class="w-4 h-4" />
                  </.button>
                </div>

                <div id="academy-list" class="space-y-2">
                  <%= if @selected_academy_ids == [] do %>
                    <div class="rounded-lg border border-dashed border-base-200 bg-base-50 px-4 py-6 text-center">
                      <.p size="text-sm" class="text-base-content/70">
                        No academies selected yet.
                      </.p>
                    </div>
                  <% else %>
                    <%= for academy_id <- @selected_academy_ids do %>
                      <% academy = Map.get(@academy_lookup, academy_id) %>
                      <div
                        id={"academy-row-#{academy_id}"}
                        class={[
                          "flex items-center gap-3 rounded-lg border border-base-200 bg-base-50 px-3 py-2",
                          @primary_academy_id == academy_id &&
                            "border-primary/40 bg-primary/5 ring-1 ring-primary/20"
                        ]}
                      >
                        <input
                          type="radio"
                          id={"primary-academy-#{academy_id}"}
                          name="primary_academy"
                          class="h-4 w-4 text-primary border-base-300 focus:ring-primary/30"
                          checked={@primary_academy_id == academy_id}
                          disabled={length(@selected_academy_ids) == 1}
                          phx-click="set_primary_academy"
                          phx-value-id={academy_id}
                          aria-label="Set primary academy"
                        />
                        <div class="flex-1 min-w-0 flex items-center justify-between gap-4">
                          <div class="min-w-0">
                            <div class="flex items-center gap-2 text-sm font-medium text-base-content truncate">
                              <span class="truncate">
                                {if academy, do: academy.name, else: "Academy"}
                              </span>
                              <span
                                :if={@primary_academy_id == academy_id}
                                class="badge badge-sm badge-primary"
                              >
                                Primary
                              </span>
                            </div>
                          </div>
                          <div class="text-right text-xs text-base-content/60">
                            {if academy,
                              do: academy_location(academy) || "Location not set",
                              else: "Location not set"}
                          </div>
                        </div>
                        <.button
                          type="button"
                          class="btn btn-ghost btn-xs"
                          phx-click="remove_academy"
                          phx-value-id={academy_id}
                          title="Remove Academy"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </.button>
                      </div>
                    <% end %>
                  <% end %>
                </div>

                <div class="flex flex-wrap items-center gap-3">
                  <.button
                    id="open-academy-drawer"
                    type="button"
                    class="btn btn-ghost btn-xs"
                    phx-click="open_academy_drawer"
                  >
                    Create academy
                  </.button>
                  <.p size="text-xs" class="text-base-content/60">
                    Add a new academy if you cannot find it.
                  </.p>
                </div>

                <div
                  :if={@show_academy_search}
                  class="rounded-xl border border-base-200 bg-base-50 px-4 py-4"
                >
                  <.search_field
                    id="academy-search-field"
                    name="query"
                    value={@academy_search_query}
                    placeholder="Search academies by name or location..."
                    phx-debounce="300"
                    phx-keyup="search_academies"
                  />

                  <%= if @academy_search_results != [] do %>
                    <div class="mt-3 space-y-2 max-h-56 overflow-y-auto">
                      <%= for academy <- @academy_search_results do %>
                        <.button
                          type="button"
                          variant="transparent"
                          content_class="flex w-full items-center justify-between"
                          phx-click="select_academy"
                          phx-value-id={academy.id}
                          class="w-full p-3 text-left rounded-lg border border-base-200 hover:bg-base-200 transition-colors"
                        >
                          <div class="text-sm font-medium text-base-content">
                            {academy.name}
                          </div>
                          <div class="text-xs text-base-content/60 text-right">
                            {academy_location(academy) || "Location not set"}
                          </div>
                        </.button>
                      <% end %>
                    </div>
                  <% else %>
                    <%= if String.length(@academy_search_query) >= 2 do %>
                      <.p size="text-sm" class="text-base-content/70 text-center py-4">
                        No academies found matching "{@academy_search_query}"
                      </.p>
                    <% else %>
                      <.p size="text-sm" class="text-base-content/70 text-center py-4">
                        Start typing to search for academies
                      </.p>
                    <% end %>
                  <% end %>

                  <div class="mt-3 flex justify-end">
                    <.button
                      id="close-academy-selector"
                      type="button"
                      class="btn btn-ghost btn-xs"
                      phx-click="close_academy_selector"
                    >
                      Cancel
                    </.button>
                  </div>
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
