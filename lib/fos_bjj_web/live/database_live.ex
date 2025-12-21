defmodule FosBjjWeb.DatabaseLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjjWeb.CoreComponents
  import FosBjjWeb.Components.ScrollArea
  import FosBjjWeb.Components.Card
  import FosBjjWeb.Components.Pagination
  import FosBjjWeb.Components.Typography
  import FosBjjWeb.Components.Button
  require Ash.Query

  on_mount {FosBjjWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:videos, [])
     |> assign(:total_videos, 0)
     |> assign(:current_page, 1)
     |> assign(:selected_technique_id, nil)}
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
        technique_id = String.to_integer(technique_id)

        Video
        |> Ash.Query.filter(techniques.id == ^technique_id)
      else
        Video
        |> Ash.Query.sort(inserted_at: :desc)
      end

    page_result =
      query
      |> Ash.Query.load([:techniques, :grips])
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
    params =
      if socket.assigns.selected_technique_id,
        do: [technique_id: socket.assigns.selected_technique_id],
        else: []

    params = params ++ [page: page]

    {:noreply, push_patch(socket, to: ~p"/database?#{params}")}
  end

  def handle_event("pagination", _params, socket), do: {:noreply, socket}

  def handle_event("select_technique", %{"technique-id" => technique_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/database?technique_id=#{technique_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="flex flex-row h-[calc(100vh-8rem)] gap-4">
        <!-- Left Side: Video List (50-60%) -->
        <div class="w-3/5 min-w-[50%] h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
          <div class="p-4 border-b border-base-200 bg-base-200/50">
            <div class="flex items-center gap-2">
              <CoreComponents.icon name="hero-film" class="w-6 h-6" />
              <.h2 class="flex items-center gap-2" font_weight="font-bold">
                <%= if @selected_technique_id do %>
                  Videos
                <% else %>
                  Recent Videos
                <% end %>
                <%= if @total_videos > 0 do %>
                  <.small class="font-normal text-base-content/60">({@total_videos})</.small>
                <% end %>
              </.h2>
            </div>
          </div>

          <.scroll_area id="video-scroll" class="flex-1 w-full" height="h-full">
            <%= if @videos == [] do %>
              <div class="flex flex-col items-center justify-center h-full p-8 text-base-content/50">
                <CoreComponents.icon name="hero-film" class="w-16 h-16 mb-4 opacity-20" />
                <.p size="large">No videos found</.p>
              </div>
            <% else %>
              <div class="flex flex-col gap-4 p-4">
                <%= for video <- @videos do %>
                  <.card class="h-full flex flex-col">
                    <div class="contents">
                      <.link
                        navigate={~p"/videos/#{video.id}"}
                        class="cursor-pointer hover:shadow-xl transition-shadow group"
                      >
                        <.card_media
                          src={video.thumbnail_url}
                          alt="Thumbnail"
                          class="aspect-video object-cover group-hover:opacity-90 transition-opacity"
                        />
                        <.card_content class="flex-1 p-6">
                          <.h3
                            font_weight="font-bold"
                            class="mb-2 group-hover:text-primary transition-colors"
                          >
                            {video.title}
                          </.h3>
                        </.card_content>
                      </.link>
                      <.p size="extra_small" class="text-base-content/70 line-clamp-3 mb-3 ml-2">
                        {video.description}
                      </.p>
                      <div class="mt-auto ml-2 pt-3 border-t border-base-200 space-y-3">
                        <%= if video.techniques && video.techniques != [] do %>
                          <div class="flex items-start gap-2">
                            <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                              Techniques
                            </span>
                            <div class="flex flex-wrap gap-2">
                              <%= for technique <- video.techniques do %>
                                <.button
                                  phx-click="select_technique"
                                  phx-value-technique-id={technique.id}
                                  size="extra_small"
                                  color="primary"
                                  rounded="full"
                                  variant="default"
                                >
                                  {technique.name}
                                </.button>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                        <%= if video.grips && video.grips != [] do %>
                          <div class="flex items-start gap-2 mb-2">
                            <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                              Grips
                            </span>
                            <div class="flex flex-wrap gap-1.5">
                              <%= for grip <- video.grips do %>
                                <span class="px-2 py-0.5 text-xs bg-secondary/20 text-secondary rounded-full border border-secondary/30">
                                  {grip.label}
                                </span>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
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

    <!-- Right Side: Technique Tree (40-50%) -->
        <div class="w-2/5 flex-1 h-full">
          <.live_component
            module={FosBjjWeb.TechniqueTreeComponent}
            id="technique-tree"
            selected_technique_id={@selected_technique_id}
            target_route="/database"
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
