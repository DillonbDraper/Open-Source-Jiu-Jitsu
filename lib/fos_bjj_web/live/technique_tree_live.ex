defmodule FosBjjWeb.TechniqueTreeComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.{
    Position,
    SubPosition,
    Technique,
    ActionSubPositionOrientation,
    VideoTechnique
  }

  import Ecto.Query
  import FosBjjWeb.Components.Icon
  import FosBjjWeb.Components.ScrollArea
  import FosBjjWeb.Components.RadioField
  import FosBjjWeb.Components.SearchField
  import FosBjjWeb.Components.Popover
  require Ash.Query

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:expanded_ids, MapSet.new())
      |> assign(:techniques_map, %{})
      |> assign(:counts_map, %{})
      |> assign(:actions_map, %{})
      |> assign(:selected_attire, "both")
      |> assign(:title_search, nil)
      |> assign(:form, to_form(%{}))

    {:ok, socket}
  end

  @impl true
  def handle_event("attire_change", %{"attire" => attire}, socket) do
    # Build query params, preserving technique_id or title search if present
    params =
      if socket.assigns.selected_technique_id do
        "technique_id=#{socket.assigns.selected_technique_id}&attire=#{attire}"
      else
        "attire=#{attire}"
      end

    params =
      if socket.assigns.title_search do
        "title=#{socket.assigns.title_search}&attire=#{attire}"
      else
        params
      end

    socket =
      socket
      |> assign(:selected_attire, attire)
      |> push_patch(to: "/database?#{params}")

    {:noreply, socket}
  end

  def handle_event("title_search", %{"title" => title_search}, socket) do
    socket =
      socket
      |> assign(:title_search, title_search)
      |> push_patch(
        to: "/database?title=#{title_search}&attire=#{socket.assigns.selected_attire}"
      )

    {:noreply, socket}
  end

  def handle_event("clear_all", _params, socket) do
    socket =
      socket
      |> assign(:expanded_ids, MapSet.new())
      |> assign(:selected_technique_id, nil)
      |> assign(:title_search, nil)
      |> assign(:selected_attire, "both")
      |> push_patch(to: "/database?attire=both")

    {:noreply, socket}
  end

  def handle_event("toggle", params, socket) do
    id = construct_id(params)
    expanded_set = socket.assigns.expanded_ids

    if MapSet.member?(expanded_set, id) do
      {:noreply, assign(socket, :expanded_ids, MapSet.delete(expanded_set, id))}
    else
      socket = assign(socket, :expanded_ids, MapSet.put(expanded_set, id))

      # Compute counts or fetch data based on level
      socket =
        case params["level"] do
          "position" ->
            position = Enum.find(socket.assigns.positions, fn p -> p.name == params["pos"] end)
            compute_orientation_counts(socket, position, params["pos"])

          "orientation" ->
            count = count_videos_for_branch(params["pos"], params["ori"], nil, nil)

            socket
            |> put_count(id, count)
            |> compute_sub_position_counts(params["pos"], params["ori"])

          "sub_position" ->
            # Load actions filtered by subposition+orientation and compute their counts
            socket
            |> maybe_load_actions(id, params["sub"], params["ori"])
            |> compute_action_counts(id, params["pos"], params["ori"], params["sub"])

          "action" ->
            count =
              count_videos_for_branch(
                params["pos"],
                params["ori"],
                params["sub"],
                params["action"]
              )

            socket
            |> put_count(id, count)
            |> maybe_fetch_techniques(id, params["ori"], params["sub"], params["action"])

          _ ->
            socket
        end

      {:noreply, socket}
    end
  end

  @impl true
  def update(assigns, socket) do
    # Detect if technique was selected
    old_technique_id = socket.assigns[:selected_technique_id]
    new_technique_id = assigns[:selected_technique_id]

    technique_selected? =
      (is_nil(old_technique_id) or
         old_technique_id != new_technique_id) and not is_nil(new_technique_id)

    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:selected_technique_id, new_technique_id)
      |> assign(:title_search, assigns[:title_search])
      |> assign(:selected_attire, assigns[:selected_attire])

    socket =
      if technique_selected? do
        assign(socket, :title_search, nil)
      else
        socket
      end

    # Load positions data only if not already loaded
    socket =
      if Map.has_key?(socket.assigns, :positions) do
        socket
      else
        positions =
          Position
          |> Ash.Query.for_read(:read)
          |> Ash.Query.load([:orientations, :video_count])
          |> Ash.read!()
          |> sort_by_label()

        sub_positions =
          SubPosition
          |> Ash.Query.for_read(:read)
          |> Ash.read!()
          |> sort_by_label()

        socket
        |> assign(:positions, positions)
        |> assign(:sub_positions, sub_positions)
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-[calc(70vh-4rem)] flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
      <div class="p-4 border-b border-base-200 bg-base-200/50 flex-shrink-0 flex justify-between items-center">
        <h2 class="text-xl font-bold flex items-center gap-2">
          <.icon name="hero-book-open" class="w-6 h-6" /> Techniques
        </h2>
        <.popover variant="shadow" color="danger" id="clear-tree-popover">
          <:trigger>
            <button
              phx-click="clear_all"
              phx-target={@myself}
              class="hover:bg-base-300 p-1 rounded-md transition-colors"
              aria-label="Clear all selections"
            >
              <.icon
                name="hero-x-circle"
                class="w-6 h-6 text-red-600 cursor-pointer hover: shadow"
              />
            </button>
          </:trigger>
          <:content class="text-s">
            Click to clear all selections
          </:content>
        </.popover>
      </div>
      <div class="px-2 py-4 flex-shrink-0">
        <.form for={@form} phx-change="attire_change" phx-target={@myself}>
          <.group_radio
            id="selected_attire"
            name="attire"
            variation="horizontal"
            space="medium"
            class="flex gap-2"
          >
            <:radio value="gi" checked={@selected_attire == "gi"}>Gi</:radio>
            <:radio value="no_gi" checked={@selected_attire == "no_gi"}>No Gi</:radio>
            <:radio value="both" checked={@selected_attire == "both"}>Both</:radio>
          </.group_radio>
        </.form>
      </div>
      <div class="px-2 pb-4 flex-shrink-0">
        <.form for={@form} phx-submit="title_search" phx-target={@myself}>
          <.search_field
            name="title"
            value={@title_search}
            label="Search By Title"
            floating="outer"
            id="title_search"
            space="medium"
            search_button
          >
          </.search_field>
        </.form>
      </div>
      <.scroll_area id="technique-tree-scroll" height="h-full" class="flex-1 w-full !h-auto">
        <div>
          <div :if={@positions == []} class="p-4 text-center text-base-content/60">
            <span class="loading loading-spinner loading-sm"></span> Loading...
          </div>

          <%= for position <- @positions do %>
            <% pos_id = "pos:#{position.name}" %>
            <.tree_node
              id={pos_id}
              label={position.label}
              count={position.video_count}
              expanded={expanded?(@expanded_ids, pos_id)}
              level={0}
              click_params={%{"level" => "position", "pos" => position.name}}
              myself={@myself}
            >
              <%= if expanded?(@expanded_ids, pos_id) do %>
                <%= for orientation <- sort_by_label(position.orientations) do %>
                  <% ori_id = "#{pos_id}:ori:#{orientation.name}" %>
                  <.tree_node
                    id={ori_id}
                    label={orientation.label}
                    count={get_count(@counts_map, ori_id)}
                    expanded={expanded?(@expanded_ids, ori_id)}
                    level={1}
                    click_params={
                      %{"level" => "orientation", "pos" => position.name, "ori" => orientation.name}
                    }
                    myself={@myself}
                  >
                    <%= if expanded?(@expanded_ids, ori_id) do %>
                      <%= for sub_pos <- filter_sub_positions(@sub_positions, position.name) do %>
                        <% sub_id = "#{ori_id}:sub:#{sub_pos.name}" %>
                        <.tree_node
                          id={sub_id}
                          label={sub_pos.label}
                          count={get_count(@counts_map, sub_id)}
                          expanded={expanded?(@expanded_ids, sub_id)}
                          level={2}
                          click_params={
                            %{
                              "level" => "sub_position",
                              "pos" => position.name,
                              "ori" => orientation.name,
                              "sub" => sub_pos.name
                            }
                          }
                          myself={@myself}
                        >
                          <%= if expanded?(@expanded_ids, sub_id) do %>
                            <%= for action <- get_actions(@actions_map, sub_id) do %>
                              <% action_id = "#{sub_id}:action:#{action.name}" %>
                              <.tree_node
                                id={action_id}
                                label={action.label}
                                count={get_count(@counts_map, action_id)}
                                expanded={expanded?(@expanded_ids, action_id)}
                                level={3}
                                click_params={
                                  %{
                                    "level" => "action",
                                    "pos" => position.name,
                                    "ori" => orientation.name,
                                    "sub" => sub_pos.name,
                                    "action" => action.name
                                  }
                                }
                                myself={@myself}
                              >
                                <%= if expanded?(@expanded_ids, action_id) do %>
                                  <div class="flex flex-col gap-1 pl-4 border-l-2 border-base-200 ml-2.5 my-1">
                                    <% techniques = get_techniques(@techniques_map, action_id) %>
                                    <%= if techniques == :loading do %>
                                      <span class="text-xs text-base-content/50 italic px-2 py-1">
                                        Loading...
                                      </span>
                                    <% else %>
                                      <%= for technique <- techniques do %>
                                        <.link
                                          patch={"/database?technique_id=#{technique.id}&attire=#{@selected_attire}"}
                                          class={[
                                            "btn btn-ghost btn-s btn-block justify-start font-normal h-auto py-1.5 px-2 text-left whitespace-normal leading-tight",
                                            @selected_technique_id == "#{technique.id}" &&
                                              "bg-primary/10 text-primary"
                                          ]}
                                        >
                                          <span class="flex-1">
                                            {technique.name} ({technique.video_count})
                                          </span>
                                        </.link>
                                      <% end %>
                                      <%= if Enum.empty?(techniques) do %>
                                        <span class="text-xs text-base-content/50 italic px-2 py-1">
                                          No techniques found
                                        </span>
                                      <% end %>
                                    <% end %>
                                  </div>
                                <% end %>
                              </.tree_node>
                            <% end %>
                          <% end %>
                        </.tree_node>
                      <% end %>
                    <% end %>
                  </.tree_node>
                <% end %>
              <% end %>
            </.tree_node>
          <% end %>
        </div>
      </.scroll_area>
    </div>
    """
  end

  attr(:id, :string, required: true)
  attr(:label, :string, required: true)
  attr(:count, :integer, default: nil)
  attr(:expanded, :boolean, required: true)
  attr(:level, :integer, default: 0)
  attr(:click_params, :map, required: true)
  attr(:myself, :any, required: true)
  slot(:inner_block)

  def tree_node(assigns) do
    ~H"""
    <div class="flex flex-col">
      <button
        phx-click="toggle"
        phx-target={@myself}
        phx-value-level={@click_params["level"]}
        phx-value-pos={@click_params["pos"]}
        phx-value-ori={@click_params["ori"]}
        phx-value-sub={@click_params["sub"]}
        phx-value-action={@click_params["action"]}
        class={[
          "flex items-center gap-2 hover:bg-base-200 p-2 rounded-lg transition-colors w-full text-left group",
          @expanded && "bg-base-200 font-medium"
        ]}
        style={"padding-left: #{@level * 0.75 + 0.5}rem"}
      >
        <%= if @expanded do %>
          <.icon
            name="hero-chevron-down"
            class="w-4 h-4 shrink-0 text-base-content/70 group-hover:text-base-content"
          />
        <% else %>
          <.icon
            name="hero-chevron-right"
            class="w-4 h-4 shrink-0 text-base-content/70 group-hover:text-base-content"
          />
        <% end %>
        <span class="text-sm select-none">
          {@label}
          <span class="text-xs opacity-60 ml-1">({@count})</span>
        </span>
      </button>
      <%= if @expanded do %>
        <div class="flex flex-col animate-in fade-in slide-in-from-top-1 duration-200">
          {render_slot(@inner_block)}
        </div>
      <% end %>
    </div>
    """
  end

  defp maybe_load_actions(socket, sub_id, sub_position_name, orientation_name) do
    if Map.has_key?(socket.assigns.actions_map, sub_id) do
      socket
    else
      # Query actions that are associated with this subposition+orientation
      actions =
        from(apo in ActionSubPositionOrientation,
          join: a in assoc(apo, :action),
          on: a.name == apo.action_name,
          where: apo.sub_position_name == ^sub_position_name,
          where: apo.orientation_name == ^orientation_name,
          select: %{name: a.name, label: a.label},
          order_by: a.label
        )
        |> FosBjj.Repo.all()

      assign(socket, :actions_map, Map.put(socket.assigns.actions_map, sub_id, actions))
    end
  end

  defp maybe_fetch_techniques(socket, id, ori_name, sub_name, action_name) do
    if Map.has_key?(socket.assigns.techniques_map, id) do
      socket
    else
      techniques =
        Technique
        |> Ash.Query.filter(sub_position_name == ^sub_name)
        |> Ash.Query.filter(orientation_name == ^ori_name)
        |> Ash.Query.filter(action_name == ^action_name)
        |> Ash.Query.load(:video_count)
        |> Ash.read!()
        |> sort_by_name()

      assign(socket, :techniques_map, Map.put(socket.assigns.techniques_map, id, techniques))
    end
  end

  defp count_videos_for_branch(position_name, orientation_name, sub_position_name, action_name) do
    query =
      from(vt in VideoTechnique,
        join: t in assoc(vt, :techniques),
        as: :technique,
        join: sp in assoc(t, :sub_position),
        as: :sub_position,
        where: sp.position_name == ^position_name,
        select: count(vt.video_id, :distinct)
      )

    query =
      if orientation_name,
        do: where(query, [technique: t], t.orientation_name == ^orientation_name),
        else: query

    query =
      if sub_position_name,
        do: where(query, [technique: t], t.sub_position_name == ^sub_position_name),
        else: query

    query =
      if action_name,
        do: where(query, [technique: t], t.action_name == ^action_name),
        else: query

    FosBjj.Repo.one(query) || 0
  end

  defp put_count(socket, id, count) do
    counts_map = socket.assigns.counts_map
    assign(socket, :counts_map, Map.put(counts_map, id, count))
  end

  defp compute_orientation_counts(socket, position, position_name) do
    Enum.reduce(position.orientations, socket, fn orientation, acc_socket ->
      ori_id = "pos:#{position_name}:ori:#{orientation.name}"
      count = count_videos_for_branch(position_name, orientation.name, nil, nil)
      put_count(acc_socket, ori_id, count)
    end)
  end

  defp compute_sub_position_counts(socket, position_name, orientation_name) do
    sub_positions = filter_sub_positions(socket.assigns.sub_positions, position_name)

    # Concerning if enough subpositions come to exist
    Enum.reduce(sub_positions, socket, fn sub_pos, acc_socket ->
      sub_id = "pos:#{position_name}:ori:#{orientation_name}:sub:#{sub_pos.name}"
      count = count_videos_for_branch(position_name, orientation_name, sub_pos.name, nil)
      put_count(acc_socket, sub_id, count)
    end)
  end

  defp compute_action_counts(socket, sub_id, position_name, orientation_name, sub_position_name) do
    actions = Map.get(socket.assigns.actions_map, sub_id, [])

    Enum.reduce(actions, socket, fn action, acc_socket ->
      action_id = "#{sub_id}:action:#{action.name}"

      count =
        count_videos_for_branch(position_name, orientation_name, sub_position_name, action.name)

      put_count(acc_socket, action_id, count)
    end)
  end

  # Dynamically construct id for tree node level
  defp construct_id(%{"level" => "position", "pos" => pos}), do: "pos:#{pos}"

  defp construct_id(%{"level" => "orientation", "pos" => pos, "ori" => ori}),
    do: "pos:#{pos}:ori:#{ori}"

  defp construct_id(%{"level" => "sub_position", "pos" => pos, "ori" => ori, "sub" => sub}),
    do: "pos:#{pos}:ori:#{ori}:sub:#{sub}"

  defp construct_id(%{
         "level" => "action",
         "pos" => pos,
         "ori" => ori,
         "sub" => sub,
         "action" => action
       }),
       do: "pos:#{pos}:ori:#{ori}:sub:#{sub}:action:#{action}"

  defp construct_id(_), do: ""

  defp expanded?(set, id), do: MapSet.member?(set, id)

  defp filter_sub_positions(sub_positions, position_name),
    do: Enum.filter(sub_positions, fn sp -> sp.position_name == position_name end)

  defp get_techniques(map, id), do: Map.get(map, id, [])
  defp get_actions(map, id), do: Map.get(map, id, [])
  defp get_count(map, id), do: Map.get(map, id)
  defp sort_by_label(list), do: Enum.sort_by(list, & &1.label)
  defp sort_by_name(list), do: Enum.sort_by(list, & &1.name)
end
