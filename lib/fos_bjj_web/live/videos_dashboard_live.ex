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
     |> assign(:title_search, "")}
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
    attire = params["attire"]
    title = params["title"]

    {:noreply,
     socket
     |> assign(:view_mode, view_mode)
     |> assign(:video_id, video_id)
     |> assign(:selected_technique_id, technique_id)
     |> assign(:selected_attire, attire)
     |> assign(:title_search, title)}
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
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
