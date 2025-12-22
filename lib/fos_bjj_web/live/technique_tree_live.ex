defmodule FosBjjWeb.TechniqueTreeComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.{Position, SubPosition, Technique}
  alias FosBjjWeb.CoreComponents
  import FosBjjWeb.Components.ScrollArea
  require Ash.Query

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:target_route, fn -> "/database" end)
      |> assign_new(:selected_technique_id, fn -> nil end)

    # Initialize data if not present (self-contained data fetching)
    if socket.assigns[:positions] do
      {:ok, socket}
    else
      positions =
        Position
        |> Ash.Query.for_read(:read)
        |> Ash.Query.load([:orientations, :actions, :video_count])
        |> Ash.read!()
        |> sort_by_label()

      sub_positions =
        SubPosition
        |> Ash.Query.for_read(:read)
        |> Ash.Query.load(:video_count)
        |> Ash.read!()
        |> sort_by_label()

      {:ok,
       socket
       |> assign(:positions, positions)
       |> assign(:sub_positions, sub_positions)
       |> assign_new(:expanded_ids, fn -> MapSet.new() end)
       |> assign_new(:techniques_map, fn -> %{} end)
       |> assign_new(:counts_map, fn -> %{} end)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
      <div class="p-4 border-b border-base-200 bg-base-200/50">
        <h2 class="text-xl font-bold flex items-center gap-2">
          <CoreComponents.icon name="hero-book-open" class="w-6 h-6" /> Techniques
        </h2>
      </div>
      <.scroll_area id="technique-tree-scroll" height="h-full" class="flex-1 w-full">
        <div class="flex flex-col gap-1 p-2">
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
                          count={sub_pos.video_count}
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
                            <%= for action <- sort_by_label(position.actions) do %>
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
                                          patch={"#{@target_route}?technique_id=#{technique.id}"}
                                          class={[
                                            "btn btn-ghost btn-xs btn-block justify-start font-normal h-auto py-1.5 px-2 text-left whitespace-normal leading-tight",
                                            @selected_technique_id == "#{technique.id}" &&
                                              "bg-primary/10 text-primary"
                                          ]}
                                        >
                                          <span class="flex-1">{technique.name}</span>
                                          <%= if technique.video_count > 0 do %>
                                            <span class="text-xs opacity-60 ml-1">
                                              ({technique.video_count})
                                            </span>
                                          <% end %>
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
          <CoreComponents.icon
            name="hero-chevron-down"
            class="w-4 h-4 shrink-0 text-base-content/70 group-hover:text-base-content"
          />
        <% else %>
          <CoreComponents.icon
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

  @impl true
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
            # Pre-compute counts for all child orientations
            position = find_position(socket.assigns.positions, params["pos"])
            compute_orientation_counts(socket, position, params["pos"])

          "orientation" ->
            # Compute count for this orientation
            count = count_videos_for_branch(params["pos"], params["ori"], nil, nil)
            put_count(socket, id, count)

          "sub_position" ->
            # Pre-compute counts for all child actions
            position = find_position(socket.assigns.positions, params["pos"])

            compute_sub_action_counts(
              socket,
              position,
              params["pos"],
              params["ori"],
              params["sub"]
            )

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
    import Ecto.Query

    query =
      from vt in "video_techniques",
        join: t in "techniques",
        on: vt.technique_id == t.id,
        join: sp in "sub_positions",
        on: sp.name == t.sub_position_name,
        where: sp.position_name == ^position_name,
        select: count(vt.video_id, :distinct)

    query =
      if orientation_name,
        do: where(query, [vt, t], t.orientation_name == ^orientation_name),
        else: query

    query =
      if sub_position_name,
        do: where(query, [vt, t], t.sub_position_name == ^sub_position_name),
        else: query

    query =
      if action_name,
        do: where(query, [vt, t], t.action_name == ^action_name),
        else: query

    FosBjj.Repo.one(query) || 0
  end

  defp put_count(socket, id, count) do
    counts_map = socket.assigns.counts_map
    assign(socket, :counts_map, Map.put(counts_map, id, count))
  end

  defp compute_orientation_counts(socket, position, position_name) do
    # Compute counts for all orientations under this position
    Enum.reduce(position.orientations, socket, fn orientation, acc_socket ->
      ori_id = "pos:#{position_name}:ori:#{orientation.name}"
      count = count_videos_for_branch(position_name, orientation.name, nil, nil)
      put_count(acc_socket, ori_id, count)
    end)
  end

  defp compute_sub_action_counts(
         socket,
         position,
         position_name,
         orientation_name,
         sub_position_name
       ) do
    # Compute counts for all actions under this sub_position
    Enum.reduce(position.actions, socket, fn action, acc_socket ->
      action_id =
        "pos:#{position_name}:ori:#{orientation_name}:sub:#{sub_position_name}:action:#{action.name}"

      count =
        count_videos_for_branch(position_name, orientation_name, sub_position_name, action.name)

      put_count(acc_socket, action_id, count)
    end)
  end

  defp find_position(positions, position_name) do
    Enum.find(positions, fn p -> p.name == position_name end)
  end

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
  defp get_count(map, id), do: Map.get(map, id)
  defp sort_by_label(list), do: Enum.sort_by(list, & &1.label)
  defp sort_by_name(list), do: Enum.sort_by(list, & &1.name)
end
