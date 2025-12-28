defmodule FosBjjWeb.VideosDashboardLive do
  use FosBjjWeb, :live_view
  import FosBjjWeb.Components.Modal
  alias FosBjjWeb.VideoLive.VideoFormComponent
  alias FosBjjWeb.TechniqueLive.NewTechniqueForm
  alias Phoenix.LiveView.JS

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
     |> assign(:total_videos, 0)
     |> assign(:show_edit_modal, false)
     |> assign(:editing_video, nil)}
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
  def handle_event("close_edit_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:editing_video, nil)}
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

  @impl true
  def handle_info({:edit_video, video_id}, socket) do
    video = Ash.get!(FosBjj.JiuJitsu.Video, video_id)

    {:noreply,
     socket
     |> assign(:show_edit_modal, true)
     |> assign(:editing_video, video)}
  end

  @impl true
  def handle_info({:video_saved, _video}, socket) do
    # Trigger a refresh of the DatabaseComponent by sending it an update
    send_update(FosBjjWeb.DatabaseComponent,
      id: "database-component",
      refresh: true
    )

    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:editing_video, nil)
     |> put_flash(:info, "Video updated successfully")}
  end

  @impl true
  def handle_info({NewTechniqueForm, {:technique_created, technique}}, socket) do
    # Forward the message to the component by sending an update
    send_update(VideoFormComponent,
      id: "edit-video-form",
      action: :technique_created,
      technique: technique
    )

    {:noreply,
     socket
     |> put_flash(:info, "Technique created successfully")
     |> push_event("js-exec", %{to: "#technique-drawer-edit-video-form", attr: "phx-remove"})}
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
              current_user={assigns[:current_user]}
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

      <%!-- Edit Video Modal --%>
      <.modal
        :if={@show_edit_modal && @editing_video}
        id="edit-video-modal"
        title="Edit Video"
        show={@show_edit_modal}
        size="triple_large"
        on_cancel={JS.push("close_edit_modal")}
      >
        <.live_component
          module={VideoFormComponent}
          id="edit-video-form"
          current_user={@current_user}
          video={@editing_video}
          on_cancel={JS.exec("data-cancel", to: "#edit-video-modal")}
        />
      </.modal>

      <%!-- Colocated hook for executing JS to close modal w/animation --%>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".JsExec">
        export default {
          mounted() {
            this.handleEvent("js-exec", ({ to, attr }) => {
              document.querySelectorAll(to).forEach((el) => {
                this.liveSocket.execJS(el, el.getAttribute(attr));
              });
            });
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
