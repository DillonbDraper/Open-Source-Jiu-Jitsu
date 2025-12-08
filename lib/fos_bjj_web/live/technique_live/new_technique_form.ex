defmodule FosBjjWeb.TechniqueLive.NewTechniqueForm do
  use FosBjjWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    positions = Ash.read!(FosBjj.JiuJitsu.Position)
    sub_positions = Ash.read!(FosBjj.JiuJitsu.SubPosition)
    orientations = Ash.read!(FosBjj.JiuJitsu.Orientation)
    grips = Ash.read!(FosBjj.JiuJitsu.Grip)

    form =
      AshPhoenix.Form.for_create(FosBjj.JiuJitsu.Technique, :create, as: "technique")
      |> to_form()

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:positions, positions)
     |> assign(:sub_positions, sub_positions)
     |> assign(:orientations, orientations)
     |> assign(:grips, grips)
     |> assign(:selected_position, nil)
     |> assign(:selected_sub_positions, [])
     |> assign(:selected_grips, [])
     |> assign(:selected_orientation, nil)
     |> assign(:child_fields_disabled, true)
     |> assign(:available_orientations, [])
     |> assign(:available_sub_positions, [])}
  end

  @impl true
  def handle_event("validate", %{"technique" => params}, socket) do
    selected_position =
      Map.get(params, "position")
      |> case do
        "" -> nil
        nil -> nil
        value -> value
      end

    selected_sub_positions =
      Map.get(params, "sub_positions", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_grips =
      Map.get(params, "grips", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_orientation = Map.get(params, "orientation_name")

    {child_fields_disabled, available_orientations} = get_orientation_options(selected_position)

    # Filter sub_positions to only show those belonging to selected position
    available_sub_positions =
      get_available_sub_positions(socket.assigns.sub_positions, selected_position)

    # Remove any sub-positions that are no longer valid for the selected position
    valid_sub_position_names = Enum.map(available_sub_positions, & &1.name)

    filtered_selected_sub_positions =
      Enum.filter(selected_sub_positions, &(&1 in valid_sub_position_names))

    updated_params =
      params
      |> Map.put("sub_positions", filtered_selected_sub_positions)
      |> Map.put("grips", selected_grips)

    form = AshPhoenix.Form.validate(socket.assigns.form, updated_params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_position, selected_position)
     |> assign(:selected_sub_positions, filtered_selected_sub_positions)
     |> assign(:selected_grips, selected_grips)
     |> assign(:selected_orientation, selected_orientation)
     |> assign(:child_fields_disabled, child_fields_disabled)
     |> assign(:available_orientations, available_orientations)
     |> assign(:available_sub_positions, available_sub_positions)}
  end

  @impl true
  def handle_event("save", %{"technique" => params}, socket) do
    selected_position = socket.assigns.selected_position
    selected_sub_positions = socket.assigns.selected_sub_positions
    selected_grips = socket.assigns.selected_grips

    # Wrap single position in a list for the relationship
    selected_positions = if selected_position, do: [selected_position], else: []

    # Merge relationship data into params
    params_with_relationships =
      params
      |> Map.put("positions", selected_positions)
      |> Map.put("sub_positions", selected_sub_positions)
      |> Map.put("grips", selected_grips)

    # Use before_submit to manage relationships manually
    before_submit = fn changeset ->
      changeset
      |> Ash.Changeset.manage_relationship(:positions, selected_positions,
        type: :append_and_remove
      )
      |> Ash.Changeset.manage_relationship(
        :sub_positions,
        selected_sub_positions,
        type: :append_and_remove
      )
      |> Ash.Changeset.manage_relationship(
        :grips,
        selected_grips,
        type: :append_and_remove
      )
    end

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params_with_relationships,
           before_submit: before_submit
         ) do
      {:ok, _technique} ->
        {:noreply,
         socket
         |> put_flash(:info, "Technique created successfully")
         |> push_navigate(to: ~p"/")}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp get_orientation_options(selected_position) do
    cond do
      is_nil(selected_position) or selected_position == "" ->
        {true, []}

      selected_position == "standing" ->
        {true, []}

      selected_position in ["back", "leg_entanglement"] ->
        {false, ["superior", "inferior"]}

      true ->
        {false, ["top", "bottom"]}
    end
  end

  defp get_available_sub_positions(all_sub_positions, selected_position) do
    if is_nil(selected_position) or selected_position == "" do
      []
    else
      Enum.filter(all_sub_positions, fn sub_position ->
        sub_position.position_name == selected_position
      end)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-2xl mx-auto">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-3xl font-bold">Add New Technique</h1>
          <.link navigate={~p"/"} class="btn btn-ghost">
            ← Back
          </.link>
        </div>

        <.form_wrapper for={@form} id="technique-form" phx-change="validate" phx-submit="save">
          <div class="space-y-6">
            <%!-- Technique Name --%>
            <.text_field
              field={@form[:name]}
              label="Technique Name"
              placeholder="Enter technique name"
              required
            />

            <%!-- Position Single Select --%>
            <.combobox
              id="position-select"
              name="technique[position]"
              label="Position"
              value={@selected_position}
              placeholder="Select a position"
              size="extra_large"
            >
              <:option :for={position <- @positions} value={position.name}>
                <%= position.label %>
              </:option>
            </.combobox>

            <%!-- Sub-Position Multi-Select --%>
            <.combobox
              id={"sub-positions-select-#{@selected_position || "none"}"}
              name="technique[sub_positions][]"
              label="Sub-Positions"
              multiple={true}
              value={@selected_sub_positions}
              placeholder={if is_nil(@selected_position), do: "Select a position first", else: "Select sub-positions"}
              disabled={is_nil(@selected_position)}
              size="extra_large"
            >
              <:option :for={sub_position <- @available_sub_positions} value={sub_position.name}>
                <%= sub_position.label %>
              </:option>
            </.combobox>

            <p :if={@child_fields_disabled} class="text-sm text-gray-500 mt-1">
              Select a position to enable Subpositions
            </p>

            <%!-- Orientation Select --%>
            <.native_select
              field={@form[:orientation_name]}
              label="Orientation"
              disabled={@child_fields_disabled}
            >
              <option value="">Select orientation</option>
              <:option :for={orientation_name <- @available_orientations} value={orientation_name}>
                <%= @orientations
                |> Enum.find(&(&1.name == orientation_name))
                |> then(& &1.label) %>
              </:option>
            </.native_select>

            <p :if={@child_fields_disabled} class="text-sm text-gray-500 mt-1">
              Select a position to enable Orientation
            </p>

            <%!-- Grips Multi-Select --%>
            <.combobox
              id="grips-select"
              name="technique[grips][]"
              label="Grips"
              multiple={true}
              value={@selected_grips}
              placeholder="Select grips (optional)"
              size="extra_large"
            >
              <:option :for={grip <- @grips} value={grip.name}>
                <%= grip.label %>
              </:option>
            </.combobox>

            <%!-- Submit Buttons --%>
            <div class="flex gap-4">
              <.button type="submit" class="btn btn-primary">
                Create Technique
              </.button>
              <.button type="button" class="btn btn-ghost" phx-click={JS.navigate(~p"/")}>
                Cancel
              </.button>
            </div>
          </div>
        </.form_wrapper>
      </div>
    </Layouts.app>
    """
  end
end
