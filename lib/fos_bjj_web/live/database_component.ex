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

  @page_size 10

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

    carousel_state_stale? =
      technique_changed? or attire_changed? or title_searched? or page_changed? or
        video_type_changed? or refresh_requested?

    socket =
      socket
      |> assign(assigns)
      |> assign(:selected_technique_id, new_technique_id)
      |> assign(:selected_attire, new_attire)
      |> assign(:title_search, new_title)
      |> assign(:current_page, new_page)
      |> assign(:selected_video_type, new_video_type)
      |> ensure_in_action_carousel_assigns()

    socket =
      if socket.assigns[:videos] == nil or carousel_state_stale? do
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

    socket =
      if carousel_state_stale? do
        reset_in_action_carousel(socket)
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

  @impl true
  def handle_event("toggle_in_action_carousel", params, socket) do
    enabled? =
      case params["mode"] do
        "normal" -> false
        "slides" -> true
        _ -> !socket.assigns.in_action_carousel_enabled
      end

    socket =
      socket
      |> assign(:in_action_carousel_enabled, enabled?)
      |> maybe_close_disabled_in_action_carousel(enabled?)

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_in_action_carousel", %{"video-id" => video_id}, socket) do
    if in_action_carousel_available?(socket.assigns) do
      carousel_page = page_to_integer(socket.assigns.current_page)
      carousel_videos = read_carousel_page(socket, carousel_page)
      carousel_index = Enum.find_index(carousel_videos, &(to_string(&1.id) == video_id))

      socket =
        case carousel_index do
          nil ->
            socket

          index ->
            socket
            |> assign(:show_in_action_carousel_modal, true)
            |> assign(:in_action_carousel_page, carousel_page)
            |> assign(:in_action_carousel_index, index)
            |> assign(:in_action_carousel_videos, carousel_videos)
            |> assign(:in_action_carousel_video, Enum.at(carousel_videos, index))
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_in_action_carousel", _params, socket) do
    {:noreply, reset_in_action_carousel(socket)}
  end

  @impl true
  def handle_event("in_action_carousel_next", _params, socket) do
    {:noreply, move_in_action_carousel(socket, 1)}
  end

  @impl true
  def handle_event("in_action_carousel_previous", _params, socket) do
    {:noreply, move_in_action_carousel(socket, -1)}
  end

  defp load_videos(socket, params, page) do
    page_int = page_to_integer(page)
    offset = page_offset(page_int)

    technique_id = params[:technique_id]
    attire = params[:attire]
    title = params[:title_search]
    video_type = DatabaseParams.normalize_video_type(params[:video_type])

    query = build_videos_query(technique_id, attire, title, video_type)

    page_result =
      query
      |> Ash.Query.load(techniques: [:video_count])
      |> Ash.read!(page: [limit: @page_size, offset: offset, count: true])

    video_type_counts = %{
      instructional: count_videos(technique_id, title, "instructional"),
      analysis: count_videos(technique_id, title, "analysis"),
      in_action: count_videos(technique_id, title, "in_action")
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
    |> Ash.Query.filter(ready == true)
    |> Ash.Query.filter(is_nil(deleted_at))
    |> Ash.Query.sort(inserted_at: :desc)
  end

  defp build_videos_count_query(technique_id, title, video_type) do
    technique_id = DatabaseParams.technique_id_for_query(technique_id)

    Video
    |> filter_by_technique(technique_id)
    |> filter_by_title(title)
    |> Ash.Query.filter(video_type_name == ^video_type)
    |> Ash.Query.filter(ready == true)
    |> Ash.Query.filter(is_nil(deleted_at))
  end

  defp count_videos(technique_id, title, video_type) do
    build_videos_count_query(technique_id, title, video_type)
    |> Ash.read!(page: [limit: 1, offset: 0, count: true])
    |> Map.fetch!(:count)
  end

  defp read_carousel_page(socket, page) do
    page_int = page_to_integer(page)

    socket.assigns
    |> video_query_params()
    |> then(fn params ->
      build_videos_query(params.technique_id, params.attire, params.title_search, "in_action")
    end)
    |> Ash.Query.load([:in_action_staging, techniques: [:video_count]])
    |> Ash.read!(page: [limit: @page_size, offset: page_offset(page_int), count: false])
    |> Map.fetch!(:results)
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

  defp ensure_in_action_carousel_assigns(socket) do
    socket
    |> assign_new(:in_action_carousel_enabled, fn -> false end)
    |> assign_new(:show_in_action_carousel_modal, fn -> false end)
    |> assign_new(:in_action_carousel_page, fn -> nil end)
    |> assign_new(:in_action_carousel_index, fn -> nil end)
    |> assign_new(:in_action_carousel_videos, fn -> [] end)
    |> assign_new(:in_action_carousel_video, fn -> nil end)
  end

  defp reset_in_action_carousel(socket) do
    socket
    |> assign(:show_in_action_carousel_modal, false)
    |> assign(:in_action_carousel_page, nil)
    |> assign(:in_action_carousel_index, nil)
    |> assign(:in_action_carousel_videos, [])
    |> assign(:in_action_carousel_video, nil)
  end

  defp maybe_close_disabled_in_action_carousel(socket, true), do: socket

  defp maybe_close_disabled_in_action_carousel(socket, false),
    do: reset_in_action_carousel(socket)

  defp move_in_action_carousel(socket, direction) when direction in [-1, 1] do
    if in_action_carousel_can_move?(socket.assigns, direction) do
      current_absolute_index = carousel_absolute_index(socket.assigns)
      target_absolute_index = current_absolute_index + direction
      target_page = div(target_absolute_index, @page_size) + 1
      target_index = rem(target_absolute_index, @page_size)

      carousel_videos =
        if target_page == socket.assigns.in_action_carousel_page do
          socket.assigns.in_action_carousel_videos
        else
          read_carousel_page(socket, target_page)
        end

      case Enum.at(carousel_videos, target_index) do
        nil ->
          socket

        video ->
          socket
          |> assign(:in_action_carousel_page, target_page)
          |> assign(:in_action_carousel_index, target_index)
          |> assign(:in_action_carousel_videos, carousel_videos)
          |> assign(:in_action_carousel_video, video)
      end
    else
      socket
    end
  end

  defp in_action_carousel_available?(assigns) do
    assigns.in_action_carousel_enabled && assigns.selected_video_type == "in_action"
  end

  defp in_action_carousel_can_move?(assigns, 1) do
    carousel_open?(assigns) && carousel_absolute_index(assigns) < assigns.total_videos - 1
  end

  defp in_action_carousel_can_move?(assigns, -1) do
    carousel_open?(assigns) && carousel_absolute_index(assigns) > 0
  end

  defp carousel_open?(assigns) do
    assigns.show_in_action_carousel_modal && not is_nil(assigns.in_action_carousel_video) &&
      is_integer(assigns.in_action_carousel_page) && is_integer(assigns.in_action_carousel_index)
  end

  defp carousel_absolute_index(assigns) do
    (assigns.in_action_carousel_page - 1) * @page_size + assigns.in_action_carousel_index
  end

  defp carousel_position(assigns) do
    if carousel_open?(assigns) do
      "#{carousel_absolute_index(assigns) + 1} of #{assigns.total_videos}"
    else
      nil
    end
  end

  defp page_to_integer(page) when is_binary(page), do: String.to_integer(page)
  defp page_to_integer(page) when is_integer(page), do: page
  defp page_to_integer(_page), do: 1

  defp page_offset(page), do: (page - 1) * @page_size

  defp video_query_params(assigns) do
    %{
      technique_id: assigns[:selected_technique_id],
      attire: assigns[:selected_attire],
      title_search: assigns[:title_search]
    }
  end

  defp in_action_source_url(%{in_action_staging: %{source_video_id: source_video_id}})
       when is_binary(source_video_id) do
    case String.trim(source_video_id) do
      "" -> nil
      video_id -> "https://www.youtube.com/watch?v=#{URI.encode_www_form(video_id)}"
    end
  end

  defp in_action_source_url(_video), do: nil

  defp attire_label(:gi), do: "Gi"
  defp attire_label("gi"), do: "Gi"
  defp attire_label(_attire), do: "No-Gi"

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
      assigns
      |> assign_new(:video_type_counts, fn ->
        %{instructional: 0, analysis: 0, in_action: 0}
      end)
      |> assign(:page_size, @page_size)
      |> assign(:in_action_carousel_available, in_action_carousel_available?(assigns))
      |> assign(:in_action_carousel_can_previous, in_action_carousel_can_move?(assigns, -1))
      |> assign(:in_action_carousel_can_next, in_action_carousel_can_move?(assigns, 1))
      |> assign(:in_action_carousel_position, carousel_position(assigns))
      |> assign(
        :in_action_carousel_source_url,
        in_action_source_url(assigns[:in_action_carousel_video])
      )

    ~H"""
    <div class="w-full h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
      <div class="border-b border-base-200 bg-base-100 px-4 pt-4">
        <div class="mb-3 flex justify-end">
          <div class="inline-flex items-center justify-end gap-2">
            <span class="text-sm font-semibold text-base-content">inAction Mode</span>

            <div
              id="in-action-carousel-control"
              class="inline-flex rounded-full border border-base-300 bg-base-100 p-1 shadow-sm"
            >
              <.button
                id="in-action-carousel-normal-toggle"
                type="button"
                variant={if(@in_action_carousel_enabled, do: "transparent", else: "default")}
                color={if(@in_action_carousel_enabled, do: "natural", else: "primary")}
                border="none"
                rounded="full"
                size="small"
                font_weight="font-semibold"
                phx-click="toggle_in_action_carousel"
                phx-target={@myself}
                phx-value-mode="normal"
                class="px-4 py-2 text-sm transition"
              >
                Normal
              </.button>
              <.button
                id="in-action-carousel-toggle"
                type="button"
                variant={if(@in_action_carousel_enabled, do: "default", else: "transparent")}
                color={if(@in_action_carousel_enabled, do: "primary", else: "natural")}
                border="none"
                rounded="full"
                size="small"
                font_weight="font-semibold"
                phx-click="toggle_in_action_carousel"
                phx-target={@myself}
                phx-value-mode="slides"
                class="px-4 py-2 text-sm transition"
              >
                Slides
              </.button>
            </div>

            <.tooltip
              id="in-action-carousel-tooltip"
              position="left"
              color="dark"
              inline={true}
              width="medium"
              text_position="left"
            >
              <:trigger>
                <span class="inline-flex size-8 items-center justify-center rounded-full text-base-content/60 transition-colors hover:bg-base-200 hover:text-primary cursor-help">
                  <.icon name="hero-information-circle" class="size-5" />
                  <span class="sr-only">About inAction Review Mode</span>
                </span>
              </:trigger>
              <:content>
                Toggle on for a floating carousel to quickly switch in action videos. Toggle off to view them as normal videos
              </:content>
            </.tooltip>
          </div>
        </div>

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
          <:tab
            active={@selected_video_type == "in_action"}
            on_select={
              JS.push("select_video_type", target: @myself, value: %{video_type: "in_action"})
            }
          >
            inAction ({@video_type_counts.in_action})
          </:tab>
          <:panel></:panel>
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
                    <%= if @in_action_carousel_available do %>
                      <button
                        id={"in-action-carousel-open-title-#{video.id}"}
                        type="button"
                        phx-click="open_in_action_carousel"
                        phx-target={@myself}
                        phx-value-video-id={video.id}
                        class="block min-w-0 text-left group/title"
                      >
                        <div class="min-w-0">
                          <.h2 font_weight="font-bold" class="break-words whitespace-normal">
                            {video.title}
                          </.h2>
                        </div>
                      </button>
                    <% else %>
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
                    <% end %>

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

                  <%= if @in_action_carousel_available do %>
                    <button
                      id={"in-action-carousel-open-card-#{video.id}"}
                      type="button"
                      phx-click="open_in_action_carousel"
                      phx-target={@myself}
                      phx-value-video-id={video.id}
                      class="block w-full cursor-pointer text-left hover:shadow-xl transition-shadow group min-w-0"
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
                    </button>
                  <% else %>
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
                  <% end %>
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

      <%= if @total_videos > @page_size do %>
        <div class="p-4 border-t border-base-200 bg-base-100">
          <.pagination
            total={ceil(@total_videos / @page_size)}
            active={@current_page}
            siblings={1}
          />
        </div>
      <% end %>

      <.modal
        :if={@show_in_action_carousel_modal && @in_action_carousel_video}
        id="in-action-carousel-modal"
        title="inAction Review"
        show
        size="quadruple_large"
        rounded="extra_large"
        content_class="space-y-5"
        on_cancel={JS.push("close_in_action_carousel", target: @myself)}
      >
        <div class="space-y-5">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2 text-xs font-semibold uppercase tracking-wide text-base-content/50">
                <span>{@in_action_carousel_position}</span>
                <span>•</span>
                <span>{attire_label(@in_action_carousel_video.attire)}</span>
                <span :if={@in_action_carousel_video.inserted_at}>•</span>
                <span :if={@in_action_carousel_video.inserted_at}>
                  Uploaded {Calendar.strftime(@in_action_carousel_video.inserted_at, "%m/%d/%Y")}
                </span>
              </div>
              <.h2 font_weight="font-bold" class="mt-1 break-words text-2xl">
                {@in_action_carousel_video.title}
              </.h2>
            </div>

            <.link
              :if={@in_action_carousel_source_url}
              href={@in_action_carousel_source_url}
              target="_blank"
              rel="noopener noreferrer"
              class="shrink-0 text-sm font-semibold text-blue-600 underline-offset-4 transition-colors hover:text-blue-700 hover:underline"
            >
              Original Source
            </.link>
          </div>

          <div
            id="in-action-carousel-player-container"
            class="overflow-hidden rounded-2xl border border-base-200 bg-black shadow-xl"
          >
            <%= if @in_action_carousel_video.hosted_video_url do %>
              <.video
                id={"in-action-carousel-player-#{@in_action_carousel_video.id}"}
                ratio="video"
                rounded="none"
                thumbnail={@in_action_carousel_video.thumbnail_url}
                controls
                preload="metadata"
                class="bg-black"
              >
                <:source src={@in_action_carousel_video.hosted_video_url} type="video/mp4" />
              </.video>
            <% else %>
              <div class="flex aspect-video items-center justify-center p-8 text-center text-white/80">
                This inAction clip is still missing its hosted video file.
              </div>
            <% end %>
          </div>

          <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-start">
            <div class="min-w-0 space-y-4">
              <.p :if={@in_action_carousel_video.description} class="text-sm text-base-content/75">
                {@in_action_carousel_video.description}
              </.p>

              <div
                :if={
                  @in_action_carousel_video.techniques && @in_action_carousel_video.techniques != []
                }
                class="space-y-2"
              >
                <p class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
                  Techniques
                </p>
                <div class="flex flex-wrap gap-1.5">
                  <%= for technique <- @in_action_carousel_video.techniques do %>
                    <.button
                      type="button"
                      phx-click="select_technique"
                      phx-target={@myself}
                      phx-value-technique-id={technique.id}
                      size="extra_small"
                      color="primary"
                      rounded="full"
                      variant="default"
                    >
                      {technique.name} ({technique.video_count})
                    </.button>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="flex items-center justify-end gap-2">
              <.button
                id="in-action-carousel-prev"
                type="button"
                phx-click="in_action_carousel_previous"
                phx-target={@myself}
                disabled={!@in_action_carousel_can_previous}
                variant="bordered"
                color="primary"
                size="small"
                rounded="full"
                icon="hero-chevron-left"
                icon_class="h-4 w-4"
                class={
                  if @in_action_carousel_can_previous,
                    do: "transition-all hover:-translate-x-0.5",
                    else: "transition-all cursor-not-allowed opacity-50"
                }
              >
                Previous
              </.button>

              <.button
                id="in-action-carousel-next"
                type="button"
                phx-click="in_action_carousel_next"
                phx-target={@myself}
                disabled={!@in_action_carousel_can_next}
                variant="default"
                color="primary"
                size="small"
                rounded="full"
                right_icon="true"
                icon="hero-chevron-right"
                icon_class="h-4 w-4"
                class={
                  if @in_action_carousel_can_next,
                    do: "transition-all hover:translate-x-0.5",
                    else: "transition-all cursor-not-allowed opacity-50"
                }
              >
                Next
              </.button>
            </div>
          </div>
        </div>
      </.modal>
    </div>
    """
  end
end
