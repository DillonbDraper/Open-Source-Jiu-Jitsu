defmodule FosBjjWeb.DatabaseComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.Video
  alias FosBjjWeb.DatabaseParams
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
    new_technique_id = Map.get(assigns, :selected_technique_id, old_technique_id)
    technique_changed? = old_technique_id != new_technique_id
    old_attire = socket.assigns[:selected_attire]
    new_attire = Map.get(assigns, :selected_attire, old_attire || "both")
    old_title = socket.assigns[:title_search]
    new_title = Map.get(assigns, :title_search, old_title)
    title_searched? = old_title != new_title
    attire_changed? = old_attire != new_attire
    old_page = socket.assigns[:current_page]
    new_page = Map.get(assigns, :current_page, old_page || 1)
    page_changed? = old_page != new_page
    old_video_type = socket.assigns[:selected_video_type] || "instructional"
    new_video_type = Map.get(assigns, :selected_video_type, old_video_type)
    video_type_changed? = old_video_type != new_video_type
    refresh_requested? = assigns[:refresh] == true

    socket =
      socket
      |> assign(assigns)
      |> assign(:selected_technique_id, new_technique_id)
      |> assign(:selected_attire, new_attire)
      |> assign(:title_search, new_title)
      |> assign(:current_page, new_page)
      |> assign(:selected_video_type, new_video_type)

    socket =
      if socket.assigns[:videos] == nil or technique_changed? or attire_changed? or
           title_searched? or page_changed? or video_type_changed? or refresh_requested? do
        params = %{
          technique_id: new_technique_id,
          attire: new_attire,
          title_search: new_title,
          video_type: new_video_type
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
  def handle_event("select_video_type", %{"video_type" => video_type}, socket) do
    selected_video_type = DatabaseParams.normalize_video_type(video_type)

    params =
      DatabaseParams.build(socket.assigns, selected_video_type: selected_video_type, page: 1)

    {:noreply, push_patch(socket, to: ~p"/database?#{params}")}
  end

  @impl true
  def handle_event("select_technique", %{"technique-id" => technique_id}, socket) do
    params = DatabaseParams.build(socket.assigns, technique_id: technique_id, page: 1)

    {:noreply, push_patch(socket, to: ~p"/database?#{params}")}
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
    video_type = DatabaseParams.normalize_video_type(params[:video_type])

    query = build_videos_query(technique_id, attire, title, video_type)

    page_result =
      query
      |> Ash.Query.load(techniques: [:video_count])
      |> Ash.read!(page: [limit: 10, offset: offset, count: true])

    video_type_counts = %{
      instructional: count_videos(technique_id, title, "instructional"),
      analysis: count_videos(technique_id, title, "analysis")
    }

    # Send total_videos to parent so it can calculate total pages for navigation
    send(self(), {:update_total_videos, page_result.count})

    socket
    |> assign(:videos, page_result.results)
    |> assign(:total_videos, page_result.count)
    |> assign(:video_type_counts, video_type_counts)
  end

  defp build_videos_query(technique_id, attire, title, video_type) do
    technique_id = DatabaseParams.technique_id_for_query(technique_id)
    attire_query_param = DatabaseParams.attire_filter_values(attire)

    Video
    |> filter_by_technique(technique_id)
    |> filter_by_title(title)
    |> Ash.Query.filter(attire in ^attire_query_param)
    |> Ash.Query.filter(video_type_name == ^video_type)
    |> Ash.Query.filter(is_nil(deleted_at))
    |> Ash.Query.sort(inserted_at: :desc)
  end

  defp build_videos_count_query(technique_id, title, video_type) do
    technique_id = DatabaseParams.technique_id_for_query(technique_id)

    Video
    |> filter_by_technique(technique_id)
    |> filter_by_title(title)
    |> Ash.Query.filter(video_type_name == ^video_type)
    |> Ash.Query.filter(is_nil(deleted_at))
  end

  defp count_videos(technique_id, title, video_type) do
    build_videos_count_query(technique_id, title, video_type)
    |> Ash.read!(page: [limit: 1, offset: 0, count: true])
    |> Map.fetch!(:count)
  end

  defp filter_by_technique(query, nil), do: query

  defp filter_by_technique(query, technique_id) do
    Ash.Query.filter(query, techniques.id == ^technique_id)
  end

  defp filter_by_title(query, nil), do: query
  defp filter_by_title(query, ""), do: query

  defp filter_by_title(query, title_string) do
    Ash.Query.filter(query, ilike(title, "%#{^title_string}%"))
  end

  defp technique_preview(techniques), do: techniques |> List.wrap() |> Enum.take(3)
  defp remaining_techniques(techniques), do: techniques |> List.wrap() |> Enum.drop(3)
  defp remaining_technique_count(techniques), do: techniques |> remaining_techniques() |> length()
  defp technique_count(techniques), do: techniques |> List.wrap() |> length()

  defp technique_button(assigns) do
    ~H"""
    <.button
      phx-click="select_technique"
      phx-target={@target}
      phx-value-technique-id={@technique.id}
      size="extra_small"
      color="primary"
      rounded="full"
      variant="default"
    >
      {@technique.name}
      <span class="text-xs opacity-70 ml-1">
        ({@technique.video_count})
      </span>
    </.button>
    """
  end

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :video_type_counts, fn ->
        %{instructional: 0, analysis: 0}
      end)

    ~H"""
    <div class="w-full h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
      <div class="border-b border-base-200 bg-base-100 px-4 pt-4">
        <.tabs
          id="database-video-type-tabs"
          color="primary"
          size="small"
          variant="pills"
          full_width_tab
          content_padding="none"
          tab_border_size="medium"
          class="[&>[role='tablist']+div]:hidden"
        >
          <:tab
            active={@selected_video_type == "instructional"}
            on_select={
              JS.push("select_video_type", target: @myself, value: %{video_type: "instructional"})
            }
          >
            Instructional ({@video_type_counts.instructional})
          </:tab>
          <:tab
            active={@selected_video_type == "analysis"}
            on_select={
              JS.push("select_video_type", target: @myself, value: %{video_type: "analysis"})
            }
          >
            Analysis ({@video_type_counts.analysis})
          </:tab>
          <:panel></:panel>
          <:panel></:panel>
        </.tabs>
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
                  <div class="pl-3 pr-3 pt-3 pb-2 border-b border-base-200 grid grid-cols-[minmax(0,1fr)_auto] items-start gap-2">
                    <.link
                      patch={~p"/videos/#{video.id}?#{DatabaseParams.build(assigns)}"}
                      class="block min-w-0 group/title"
                    >
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
                    patch={~p"/videos/#{video.id}?#{DatabaseParams.build(assigns)}"}
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

                      <div class="flex-1 min-w-0 flex flex-col justify-between">
                        <.p size="small" class="text-base-content/70 line-clamp-5">
                          {video.description}
                        </.p>
                      </div>
                    </div>
                  </.link>
                  <div class="p-3 pt-2 border-t border-base-200">
                    <div class="flex gap-3">
                      <div class="w-4/5 min-w-0 space-y-2">
                        <%= if video.techniques && video.techniques != [] do %>
                          <div class="flex items-start gap-2">
                            <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                              Techniques
                            </span>
                            <div class="flex flex-wrap items-center gap-1.5">
                              <%= for technique <- technique_preview(video.techniques) do %>
                                <.technique_button technique={technique} target={@myself} />
                              <% end %>

                              <.popover
                                :if={remaining_technique_count(video.techniques) > 0}
                                id={"video-#{video.id}-technique-cloud"}
                                clickable
                                position="bottom"
                                width="quadruple_large"
                                padding="medium"
                                rounded="large"
                                content_class="max-h-72 overflow-y-auto shadow-xl"
                              >
                                <:trigger>
                                  <button
                                    type="button"
                                    id={"video-#{video.id}-technique-cloud-trigger"}
                                    class="inline-flex items-center rounded-full border border-primary/20 bg-primary/10 px-2 py-0.5 text-xs font-semibold text-primary transition-colors hover:bg-primary/15"
                                  >
                                    +{remaining_technique_count(video.techniques)} more
                                  </button>
                                </:trigger>
                                <:content>
                                  <div class="space-y-3 text-left">
                                    <div class="flex items-center justify-between gap-3 border-b border-base-200 pb-2">
                                      <span class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                                        Techniques covered
                                      </span>
                                      <span class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-semibold text-primary">
                                        {technique_count(video.techniques)} total
                                      </span>
                                    </div>
                                    <div class="flex flex-wrap gap-1.5">
                                      <%= for technique <- video.techniques do %>
                                        <.technique_button technique={technique} target={@myself} />
                                      <% end %>
                                    </div>
                                  </div>
                                </:content>
                              </.popover>
                            </div>
                          </div>
                        <% end %>
                      </div>

                      <div class="w-1/5 min-w-[110px] flex flex-col items-end justify-end gap-1 shrink-0">
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

                        <span class="text-xs text-base-content/60 italic whitespace-nowrap text-right">
                          Uploaded: {Calendar.strftime(video.inserted_at, "%m/%d/%Y")}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </.card>
            <% end %>
          </div>
        <% end %>
      </.scroll_area>

      <%= if @total_videos > 10 do %>
        <div class="p-4 border-t border-base-200 bg-base-100">
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
