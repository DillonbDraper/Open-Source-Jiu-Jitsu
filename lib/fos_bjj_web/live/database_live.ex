defmodule FosBjjWeb.DatabaseLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjjWeb.CoreComponents
  import FosBjjWeb.Components.ScrollArea
  import FosBjjWeb.Components.Card
  import FosBjjWeb.Components.Pagination
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok,
       socket
       |> assign(:videos, [])
       |> assign(:total_videos, 0)
       |> assign(:current_page, 1)
       |> assign(:selected_technique_id, nil)}
    else
      {:ok,
       socket
       |> assign(:videos, [])
       |> assign(:total_videos, 0)
       |> assign(:current_page, 1)
       |> assign(:selected_technique_id, nil)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    technique_id = params["technique_id"]
    page = String.to_integer(params["page"] || "1")

    load_videos(socket, technique_id, page)
  end

  defp load_videos(socket, technique_id, page) do
    offset = (page - 1) * 10

    query =
      if technique_id do
        Video
        |> Ash.Query.filter(technique_id == ^technique_id)
      else
        Video
        |> Ash.Query.sort(inserted_at: :desc)
      end

    page_result =
      query
      |> Ash.Query.load(:technique)
      |> Ash.read!(page: [limit: 10, offset: offset, count: true])

    {:noreply,
     socket
     |> assign(:videos, page_result.results)
     |> assign(:total_videos, page_result.count)
     |> assign(:current_page, page)
     |> assign(:selected_technique_id, technique_id)}
  end

  @impl true
  def handle_event("pagination", %{"action" => "select", "page" => page}, socket) do
    params = if socket.assigns.selected_technique_id, do: [technique_id: socket.assigns.selected_technique_id], else: []
    params = params ++ [page: page]

    {:noreply, push_patch(socket, to: ~p"/database?#{params}")}
  end

  def handle_event("pagination", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-row h-[calc(100vh-8rem)] gap-4">
      <!-- Left Side: Video Cards (75%) -->
      <div class="w-3/4 h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
        <div class="p-4 border-b border-base-200 bg-base-200/50">
          <h2 class="text-xl font-bold flex items-center gap-2">
            <CoreComponents.icon name="hero-film" class="w-6 h-6" />
            <%= if @selected_technique_id do %>
              Videos
            <% else %>
              Recent Videos
            <% end %>
            <%= if @total_videos > 0 do %>
              <span class="text-sm font-normal text-base-content/60">({@total_videos})</span>
            <% end %>
          </h2>
        </div>

        <.scroll_area id="video-scroll" class="flex-1 w-full" height="h-full">
          <%= if @videos == [] do %>
            <div class="flex flex-col items-center justify-center h-full p-8 text-base-content/50">
              <CoreComponents.icon name="hero-film" class="w-16 h-16 mb-4 opacity-20" />
              <p class="text-lg">No videos found</p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 p-4">
              <%= for video <- @videos do %>
                <.card class="h-full flex flex-col">
                  <.card_media src={video.thumbnail_url} alt="Thumbnail" class="aspect-video object-cover" />
                  <.card_content class="flex-1">
                    <h3 class="font-bold text-lg mb-2">{video.technique.name}</h3>
                    <p class="text-sm text-base-content/70 line-clamp-3">{video.description}</p>
                  </.card_content>
                </.card>
              <% end %>
            </div>
          <% end %>
        </.scroll_area>

        <%= if @total_videos > 10 do %>
          <div class="p-4 border-t border-base-200 bg-base-100 flex justify-center">
            <.pagination
              total={ceil(@total_videos / 10)}
              active={@current_page}
              siblings={1}
            />
          </div>
        <% end %>
      </div>

      <!-- Right Side: Technique Tree (25%) -->
      <div class="w-1/4 h-full">
         <.live_component
            module={FosBjjWeb.TechniqueTreeComponent}
            id="technique-tree"
            selected_technique_id={@selected_technique_id}
            target_route="/database"
         />
      </div>
    </div>
    """
  end
end
