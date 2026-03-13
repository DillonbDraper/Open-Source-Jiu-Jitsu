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
    # Check for changes changed BEFORE assigning new values
    old_technique_id = socket.assigns[:selected_technique_id]
    new_technique_id = assigns.selected_technique_id
    technique_changed? = old_technique_id != new_technique_id
    old_attire = socket.assigns[:selected_attire]
    new_attire = assigns.selected_attire
    old_title = socket.assigns[:title_search]
    new_title = assigns.title_search
    title_searched? = old_title != new_title
    attire_changed? = old_attire != new_attire
    old_page = socket.assigns[:current_page]
    new_page = assigns.current_page
    page_changed? = old_page != new_page
    refresh_requested? = assigns[:refresh] == true

    socket = assign(socket, assigns)

    socket =
      if socket.assigns[:videos] == nil or technique_changed? or attire_changed? or
           title_searched? or page_changed? or refresh_requested? do
        params = %{
          technique_id: new_technique_id,
          attire: new_attire,
          title_search: new_title
        }

        load_videos(socket, params, new_page)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("pagination", params, socket) do
    send(self(), {:pagination, params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_technique", %{"technique-id" => technique_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/database?technique_id=#{technique_id}")}
  end

  @impl true
  def handle_event("edit_video", %{"video-id" => video_id}, socket) do
    send(self(), {:edit_video, video_id})
    {:noreply, socket}
  end

  defp load_videos(socket, params, page) do
    page_int = if is_binary(page), do: String.to_integer(page), else: page
    offset = (page_int - 1) * 10

    technique_id = params[:technique_id]
    attire = params[:attire]
    title = params[:title_search]

    query = build_videos_query(technique_id, attire, title)

    page_result =
      query
      |> Ash.Query.load(techniques: [:video_count], grips: [])
      |> Ash.read!(page: [limit: 10, offset: offset, count: true])

    # Send total_videos to parent so it can calculate total pages for navigation
    send(self(), {:update_total_videos, page_result.count})

    socket
    |> assign(:videos, page_result.results)
    |> assign(:total_videos, page_result.count)
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

    query
    |> Ash.Query.filter(attire in ^attire_query_param)
    |> Ash.Query.filter(is_nil(deleted_at))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
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
                  <div class="pl-3 pr-3 pt-3 pb-2 border-b border-base-200 grid grid-cols-[minmax(0,1fr)_auto] items-start gap-2">
                    <.link patch={~p"/videos/#{video.id}"} class="block min-w-0 group/title">
                      <div class="min-w-0">
                        <.h2 font_weight="font-bold" class="break-words whitespace-normal">
                          {video.title}
                        </.h2>
                      </div>
                    </.link>

                    <%= if assigns[:current_user] && FosBjj.Accounts.User.admin?(@current_user) do %>
                      <.button
                        type="button"
                        variant="transparent"
                        phx-click="edit_video"
                        phx-target={@myself}
                        phx-value-video-id={video.id}
                        class="p-2 rounded-full bg-primary/10 hover:bg-primary/20 transition-colors shrink-0"
                        title="Edit video"
                      >
                        <.icon name="hero-pencil-solid" class="w-4 h-4" />
                      </.button>
                    <% end %>
                  </div>

                  <.link
                    patch={~p"/videos/#{video.id}"}
                    class="block cursor-pointer hover:shadow-xl transition-shadow group min-w-0"
                  >
                    <div class="flex gap-4 p-3">
                      <div class="flex-shrink-0 w-48 relative">
                        <.card_media
                          src={video.thumbnail_url}
                          alt="Thumbnail"
                          class="object-contain group-hover:opacity-90 transition-opacity rounded"
                        />
                      </div>

                      <div class="flex-1 flex items-start">
                        <.p size="small" class="text-base-content/70 line-clamp-5">
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
                                <span class="px-2 py-0.5 text-xs font-medium bg-secondary/10 text-secondary rounded-full border border-secondary/20">
                                  {grip.label}
                                </span>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>

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
          <.pagination
            total={ceil(@total_videos / 10)}
            active={@current_page}
            siblings={1}
          />
        </div>
      <% end %>
    </div>
    """
  end
end
