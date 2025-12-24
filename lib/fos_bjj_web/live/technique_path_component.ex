defmodule FosBjjWeb.TechniquePathComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.Technique
  import FosBjjWeb.Components.Breadcrumb
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :path_segments, [])}
  end

  @impl true
  def update(%{technique_id: nil, title_search: nil} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:path_segments, [])}
  end

  # TODO Fix path component never hitting title condition
  def update(%{technique_id: technique_id} = assigns, socket) when not is_nil(technique_id) do
    path_segments = load_technique_path(technique_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:path_segments, path_segments)}
  end

  def update(%{title_search: title} = assigns, socket) do
    path_segments = [%{label: "Search By Title: #{title}"}]

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:path_segments, path_segments)}
  end

  defp load_technique_path(technique_id) when is_binary(technique_id) do
    load_technique_path(String.to_integer(technique_id))
  end

  defp load_technique_path(technique_id) do
    case Technique
         |> Ash.Query.filter(id == ^technique_id)
         |> Ash.Query.load([:positions, :orientation, :sub_position, :action, :video_count])
         |> Ash.read_one() do
      {:ok, nil} ->
        []

      {:ok, technique} ->
        build_path_segments(technique)

      {:error, _} ->
        []
    end
  end

  defp build_path_segments(technique) do
    segments = []

    # Add Position (get first position from many_to_many)
    segments =
      if is_list(technique.positions) && technique.positions != [] do
        position = List.first(technique.positions)
        [%{label: position.label, type: :position} | segments]
      end

    # Add Orientation (optional)
    segments =
      if technique.orientation && !match?(%Ash.NotLoaded{}, technique.orientation) do
        [%{label: technique.orientation.label, type: :orientation} | segments]
      end

    # Add SubPosition (through sub_position relationship)
    segments =
      if technique.sub_position && !match?(%Ash.NotLoaded{}, technique.sub_position) do
        [%{label: technique.sub_position.label, type: :sub_position} | segments]
      end

    segments =
      if technique.action && !match?(%Ash.NotLoaded{}, technique.action) do
        [%{label: technique.action.label, type: :action} | segments]
      end

    segments =
      [%{label: "#{technique.name} (#{technique.video_count})", type: :technique} | segments]

    Enum.reverse(segments)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <%= if @path_segments != [] do %>
        <.breadcrumb
          size="medium"
          color=""
          separator_icon="hero-chevron-right"
          class="bg-base-200/30 rounded-lg border border-base-300 px-4 py-3"
        >
          <:item :for={segment <- @path_segments}>
            {segment.label}
          </:item>
        </.breadcrumb>
      <% end %>
    </div>
    """
  end
end
