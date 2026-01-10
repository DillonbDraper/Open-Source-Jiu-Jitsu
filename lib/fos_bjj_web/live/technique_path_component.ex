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
    technique =
      Technique
      |> Ash.Query.filter(id == ^technique_id)
      |> Ash.Query.load([{:sub_position, :position}, :orientation, :action, :video_count])
      |> Ash.read_one()

    case technique do
      {:ok, nil} ->
        []

      {:ok, technique} ->
        build_path_segments(technique)

      _ ->
        []
    end
  end

  defp build_path_segments(technique) do
    segments = []

    segments =
      if technique.sub_position &&
           technique.sub_position.position do
        [%{label: technique.sub_position.position.label, type: :position} | segments]
      else
        segments
      end

    segments =
      if technique.orientation do
        [%{label: technique.orientation.label, type: :orientation} | segments]
      else
        segments
      end

    segments =
      if technique.sub_position do
        [%{label: technique.sub_position.label, type: :sub_position} | segments]
      else
        segments
      end

    segments =
      if technique.action do
        [%{label: technique.action.label, type: :action} | segments]
      else
        segments
      end

    segments =
      [%{label: "#{technique.name}", type: :technique} | segments]

    Enum.reverse(segments)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <%= if @path_segments != [] do %>
        <.breadcrumb
          size="extra_large"
          color=""
          separator_icon="hero-chevron-right"
          class="bg-base-200/30 rounded-lg border border-base-300 px-4 py-3"
        >
          <:item :for={segment <- @path_segments}>
            {segment.label}
          </:item>
        </.breadcrumb>
      <% else %>
        <div class="4 border-b border-base-200 bg-base-200/50">
          <div class="flex items-center gap-2">
            <.h2 class="flex items-center gap-2">
              Recent Videos
            </.h2>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
