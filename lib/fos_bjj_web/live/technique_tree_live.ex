defmodule FosBjjWeb.TechniqueTreeLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.{Position, SubPosition, Technique}
  alias FosBjjWeb.CoreComponents
  import FosBjjWeb.Components.ScrollArea
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      positions =
        Position
        |> Ash.Query.for_read(:read)
        |> Ash.Query.load(:orientations)
        |> Ash.read!()
        |> sort_by_label()

      sub_positions =
        SubPosition
        |> Ash.Query.for_read(:read)
        |> Ash.read!()
        |> sort_by_label()

      {:ok,
       socket
       |> assign(:positions, positions)
       |> assign(:sub_positions, sub_positions)
       |> assign(:expanded_ids, MapSet.new())
       |> assign(:techniques_map, %{})}
    else
      {:ok,
       socket
       |> assign(:positions, [])
       |> assign(:sub_positions, [])
       |> assign(:expanded_ids, MapSet.new())
       |> assign(:techniques_map, %{})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full w-full bg-base-100 rounded-lg shadow-lg border border-base-200">
      <div class="p-4 border-b border-base-200 bg-base-200/50">
        <h2 class="text-xl font-bold flex items-center gap-2">
          <CoreComponents.icon name="hero-book-open" class="w-6 h-6" />
          Techniques
        </h2>
      </div>
      <.scroll_area id="technique-tree-scroll" height="h-[600px]" class="w-full">
        <div class="flex flex-col gap-1 p-2">
          <div :if={@positions == []} class="p-4 text-center text-base-content/60">
            <span class="loading loading-spinner loading-sm"></span> Loading...
          </div>

          <%= for position <- @positions do %>
            <% pos_id = "pos:#{position.name}" %>
            <.tree_node
              id={pos_id}
              label={position.label}
              expanded={expanded?(@expanded_ids, pos_id)}
              level={0}
              click_params={%{"level" => "position", "pos" => position.name}}
            >
              <%= if expanded?(@expanded_ids, pos_id) do %>
                <%= for orientation <- sort_by_label(position.orientations) do %>
                   <% ori_id = "#{pos_id}:ori:#{orientation.name}" %>
                   <.tree_node
                      id={ori_id}
                      label={orientation.label}
                      expanded={expanded?(@expanded_ids, ori_id)}
                      level={1}
                      click_params={%{"level" => "orientation", "pos" => position.name, "ori" => orientation.name}}
                   >
                      <%= if expanded?(@expanded_ids, ori_id) do %>
                        <%= for sub_pos <- filter_sub_positions(@sub_positions, position.name) do %>
                            <% sub_id = "#{ori_id}:sub:#{sub_pos.name}" %>
                            <.tree_node
                              id={sub_id}
                              label={sub_pos.label}
                              expanded={expanded?(@expanded_ids, sub_id)}
                              level={2}
                              click_params={%{"level" => "sub_position", "pos" => position.name, "ori" => orientation.name, "sub" => sub_pos.name}}
                            >
                                <%= if expanded?(@expanded_ids, sub_id) do %>
                                   <div class="flex flex-col gap-1 pl-4 border-l-2 border-base-200 ml-2.5 my-1">
                                     <% techniques = get_techniques(@techniques_map, sub_id) %>
                                     <%= if techniques == :loading do %>
                                         <span class="text-xs text-base-content/50 italic px-2 py-1">Loading...</span>
                                     <% else %>
                                         <%= for technique <- techniques do %>
                                            <.link navigate={~p"/techniques/#{technique.id}"} class="btn btn-ghost btn-xs btn-block justify-start font-normal h-auto py-1.5 px-2 text-left whitespace-normal leading-tight">
                                               {technique.name}
                                            </.link>
                                         <% end %>
                                         <%= if Enum.empty?(techniques) do %>
                                             <span class="text-xs text-base-content/50 italic px-2 py-1">No techniques found</span>
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
        </div>
      </.scroll_area>
    </div>
    """
  end

  attr(:id, :string, required: true)
  attr(:label, :string, required: true)
  attr(:expanded, :boolean, required: true)
  attr(:level, :integer, default: 0)
  attr(:click_params, :map, required: true)
  slot(:inner_block)

  def tree_node(assigns) do
    ~H"""
    <div class="flex flex-col">
      <button
        phx-click="toggle"
        phx-value-level={@click_params["level"]}
        phx-value-pos={@click_params["pos"]}
        phx-value-ori={@click_params["ori"]}
        phx-value-sub={@click_params["sub"]}
        class={[
            "flex items-center gap-2 hover:bg-base-200 p-2 rounded-lg transition-colors w-full text-left group",
            @expanded && "bg-base-200 font-medium"
        ]}
        style={"padding-left: #{@level * 0.75 + 0.5}rem"}
      >
        <%= if @expanded do %>
           <CoreComponents.icon name="hero-chevron-down" class="w-4 h-4 shrink-0 text-base-content/70 group-hover:text-base-content" />
        <% else %>
           <CoreComponents.icon name="hero-chevron-right" class="w-4 h-4 shrink-0 text-base-content/70 group-hover:text-base-content" />
        <% end %>
        <span class="text-sm select-none">{@label}</span>
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

      # If expanding a sub-position, fetch techniques
      socket =
        if params["level"] == "sub_position" do
          maybe_fetch_techniques(socket, id, params["ori"], params["sub"])
        else
          socket
        end

      {:noreply, socket}
    end
  end

  defp maybe_fetch_techniques(socket, id, ori_name, sub_name) do
    if Map.has_key?(socket.assigns.techniques_map, id) do
      socket
    else
      # Fetch techniques directly filtering by sub_position_name and orientation
      techniques =
        Technique
        |> Ash.Query.filter(sub_position_name == ^sub_name)
        |> Ash.Query.filter(orientation_name == ^ori_name)
        |> Ash.read!()
        |> sort_by_name()

      assign(socket, :techniques_map, Map.put(socket.assigns.techniques_map, id, techniques))
    end
  end

  defp construct_id(%{"level" => "position", "pos" => pos}), do: "pos:#{pos}"

  defp construct_id(%{"level" => "orientation", "pos" => pos, "ori" => ori}),
    do: "pos:#{pos}:ori:#{ori}"

  defp construct_id(%{"level" => "sub_position", "pos" => pos, "ori" => ori, "sub" => sub}),
    do: "pos:#{pos}:ori:#{ori}:sub:#{sub}"

  defp construct_id(_), do: ""

  defp expanded?(set, id), do: MapSet.member?(set, id)

  defp filter_sub_positions(sub_positions, position_name) do
    Enum.filter(sub_positions, fn sp -> sp.position_name == position_name end)
  end

  defp get_techniques(map, id) do
    Map.get(map, id, [])
  end

  defp sort_by_label(list), do: Enum.sort_by(list, & &1.label)
  defp sort_by_name(list), do: Enum.sort_by(list, & &1.name)
end
