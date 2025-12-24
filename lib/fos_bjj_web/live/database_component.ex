defmodule FosBjjWeb.DatabaseComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.Video
  import FosBjjWeb.Components.ScrollArea
  import FosBjjWeb.Components.Card
  import FosBjjWeb.Components.Pagination
  import FosBjjWeb.Components.Typography
  import FosBjjWeb.Components.Button
  import FosBjjWeb.Components.Tooltip
  import FosBjjWeb.Components.Icon
  require Ash.Query

  @impl true
  def update(assigns, socket) do
    # Check if technique_id changed BEFORE assigning new values
    old_technique_id = socket.assigns[:selected_technique_id]
    new_technique_id = assigns.selected_technique_id
    technique_changed? = old_technique_id != new_technique_id
    old_attire = socket.assigns[:selected_attire]
    new_attire = assigns.selected_attire
    old_title = socket.assigns[:title_search]
    new_title = assigns.title_search
    title_searched? = old_title != new_title
    attire_changed? = old_attire != new_attire
    socket = assign(socket, assigns)

    socket =
      if socket.assigns[:videos] == nil or technique_changed? or attire_changed? or
           title_searched? do
        params = %{
          technique_id: new_technique_id,
          attire: new_attire,
          title_search: new_title
        }

        load_videos(socket, params, 1)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("pagination", %{"action" => "select", "page" => page}, socket) do
    socket = load_videos(socket, socket.assigns.selected_technique_id, String.to_integer(page))
    {:noreply, socket}
  end

  def handle_event("pagination", _params, socket), do: {:noreply, socket}

  def handle_event("select_technique", %{"technique-id" => technique_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/database?technique_id=#{technique_id}")}
  end

  defp load_videos(socket, params, page) do
    offset = (page - 1) * 10

    technique_id = params[:technique_id]
    attire = params[:attire]
    title = params[:title_search]

    query = build_videos_query(technique_id, attire, title)

    page_result =
      query
      |> Ash.Query.load(techniques: [:video_count], grips: [])
      |> Ash.read!(page: [limit: 10, offset: offset, count: true])

    socket
    |> assign(:videos, page_result.results)
    |> assign(:total_videos, page_result.count)
    |> assign(:current_page, page)
  end

  defp build_videos_query(technique_id, attire, title) do
    attire_query_param =
      if is_nil(attire) or attire == "both" do
        ["gi", "no_gi"]
      else
        String.to_atom(attire) |> List.wrap()
      end

    query =
      case title do
        nil ->
          if technique_id do
            technique_id_int =
              if is_binary(technique_id), do: String.to_integer(technique_id), else: technique_id

            Video
            |> Ash.Query.filter(techniques.id == ^technique_id_int)
          else
            Video
            |> Ash.Query.sort(inserted_at: :desc)
          end

        title_string ->
          Video |> Ash.Query.filter(ilike(title, "%#{^title_string}%"))
      end

    query |> Ash.Query.filter(attire in ^attire_query_param)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
      <div class="p-4 border-b border-base-200 bg-base-200/50">
        <div class="flex items-center gap-2">
          <.h2 class="flex items-center gap-2" font_weight="font-bold">
            <%= if is_nil(@selected_technique_id) do %>
              Recent Videos
            <% end %>
          </.h2>
        </div>
      </div>

      <.scroll_area id="video-scroll" class="flex-1 w-full" height="h-full">
        <%= if @videos == [] do %>
          <div class="flex flex-col items-center justify-center h-full p-8 text-base-content/50">
            <.p size="large">No videos found</.p>
          </div>
        <% else %>
          <div class="flex flex-col gap-3 p-4">
            <%= for video <- @videos do %>
              <.card class="h-full flex flex-col relative">
                <div class="contents">
                  <.link
                    patch={~p"/videos/#{video.id}"}
                    class="cursor-pointer hover:shadow-xl transition-shadow group"
                  >
                    <%!-- Title at top --%>
                    <div class="px-3 pt-3 pb-2 border-b border-base-200">
                      <.h2 font_weight="font-bold">
                        {video.title}
                      </.h2>
                    </div>

                    <%!-- Horizontal layout: thumbnail on left, description on right --%>
                    <div class="flex gap-4 p-3">
                      <div class="flex-shrink-0 w-48 relative">
                        <.card_media
                          src={video.thumbnail_url}
                          alt="Thumbnail"
                          class="object-contain group-hover:opacity-90 transition-opacity rounded"
                        />
                      </div>

                      <div class="flex-1 flex items-start">
                        <.p size="small" class="text-base-content/70 line-clamp-3">
                          {video.description}
                        </.p>
                      </div>
                    </div>
                  </.link>
                  <div class="p-3 pt-2 border-t border-base-200 space-y-2">
                    <%= if video.techniques && video.techniques != [] do %>
                      <div class="flex items-start gap-2">
                        <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                          Techniques
                        </span>
                        <div class="flex flex-wrap gap-1.5">
                          <%= for technique <- video.techniques do %>
                            <.button
                              phx-click="select_technique"
                              phx-target={@myself}
                              phx-value-technique-id={technique.id}
                              size="extra_small"
                              color="primary"
                              rounded="full"
                              variant="default"
                            >
                              {technique.name}
                              <span class="text-xs opacity-70 ml-1">
                                ({technique.video_count})
                              </span>
                            </.button>
                          <% end %>
                        </div>
                      </div>
                    <% end %>

                    <div class="flex items-end justify-between gap-2">
                      <div class="flex-1">
                        <%= if video.grips && video.grips != [] do %>
                          <div class="flex items-start gap-2">
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

                      <%!-- Gi/No-Gi Indicator --%>
                      <.tooltip position="left" inline={true}>
                        <:trigger>
                          <span class={[
                            "inline-flex transition-all",
                            if(video.attire == :gi,
                              do: "text-green-600 opacity-100",
                              else: "text-gray-400 opacity-100"
                            )
                          ]}>
                            <.icon name="custom-gi" class="w-6 h-6" />
                          </span>
                        </:trigger>
                        <:content>
                          {if video.attire == :gi, do: "Gi", else: "No-Gi"}
                        </:content>
                      </.tooltip>
                    </div>
                  </div>
                </div>
              </.card>
            <% end %>
          </div>
        <% end %>
      </.scroll_area>

      <%= if @total_videos > 10 do %>
        <div class="p-4 border-t border-base-200 bg-base-100 flex justify-center">
          <.pagination total={ceil(@total_videos / 10)} active={@current_page} siblings={1} />
        </div>
      <% end %>
    </div>
    """
  end
end
