defmodule FosBjjWeb.VideosDashboardLive do
  use FosBjjWeb, :live_view

  on_mount {FosBjjWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:view_mode, :database)
     |> assign(:video_id, nil)
     |> assign(:selected_technique_id, nil)
     |> assign(:selected_attire, "both")
     |> assign(:title_search, nil)
     |> assign(:total_videos, 0)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Determine view mode based on presence of video_id param
    {view_mode, video_id} =
      case params do
        %{"id" => id} -> {:video_show, id}
        _ -> {:database, nil}
      end

    technique_id = params["technique_id"]
    attire = params["attire"] || socket.assigns[:selected_attire] || "both"
    title = params["title"] || socket.assigns[:title_search] || nil

    page =
      case params["page"] do
        nil -> 1
        page_str when is_binary(page_str) -> String.to_integer(page_str)
        page_int when is_integer(page_int) -> page_int
      end

    {:noreply,
     socket
     |> assign(:view_mode, view_mode)
     |> assign(:video_id, video_id)
     |> assign(:selected_technique_id, technique_id)
     |> assign(:selected_attire, attire)
     |> assign(:title_search, title)
     |> assign(:current_page, page)}
  end

  @impl true
  def handle_event("pagination", params, socket) do
    # Calculate the target page based on the action
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

    url_params = build_url_params(socket, page)

    {:noreply, push_patch(socket, to: ~p"/database?#{url_params}")}
  end

  @impl true
  def handle_info({:update_total_videos, total}, socket) do
    {:noreply, assign(socket, :total_videos, total)}
  end

  @impl true
  def handle_info({:pagination, params}, socket) do
    page = params["page"]

    url_params = build_url_params(socket, page)

    {:noreply, push_patch(socket, to: ~p"/database?#{url_params}")}
  end

  defp build_url_params(socket, page) do
    # Build URL params preserving current filters
    url_params = []

    url_params =
      if socket.assigns.selected_technique_id,
        do: [technique_id: socket.assigns.selected_technique_id] ++ url_params,
        else: url_params

    url_params =
      if socket.assigns.selected_attire && socket.assigns.selected_attire != "both",
        do: [attire: socket.assigns.selected_attire] ++ url_params,
        else: url_params

    url_params =
      if socket.assigns.title_search && socket.assigns.title_search != "",
        do: [title: socket.assigns.title_search] ++ url_params,
        else: url_params

    [page: page] ++ url_params
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]} full_width={true}>
      <!-- Technique Path Breadcrumb -->
      <.live_component
        module={FosBjjWeb.TechniquePathComponent}
        id="technique-path"
        technique_id={@selected_technique_id}
        title_search={@title_search}
      />

      <div class="grid grid-cols-5 gap-8 h-[calc(100vh-12rem)] w-full mt-4">
        <!-- Left: Dynamic Content Area (60% = 3 cols) -->
        <div class="col-span-3 h-full flex flex-col min-w-0 overflow-hidden">
          <%= if @view_mode == :database do %>
            <.live_component
              module={FosBjjWeb.DatabaseComponent}
              id="database-component"
              selected_technique_id={@selected_technique_id}
              selected_attire={@selected_attire}
              title_search={@title_search}
              current_page={@current_page || 1}
            />
          <% else %>
            <.live_component
              module={FosBjjWeb.VideoShowComponent}
              id="video-show-component"
              video_id={@video_id}
              selected_technique_id={@selected_technique_id}
            />
          <% end %>
        </div>

    <!-- Right: Technique Tree (40% = 2 cols, always mounted) -->
        <div class="col-span-2 min-w-0">
          <.live_component
            module={FosBjjWeb.TechniqueTreeComponent}
            id="technique-tree"
            selected_technique_id={@selected_technique_id}
            title_search={@title_search}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
