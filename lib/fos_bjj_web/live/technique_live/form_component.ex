defmodule FosBjjWeb.TechniqueLive.TechniqueForm do
  use FosBjjWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      if socket.assigns[:form] do
        socket
      else
        positions = Ash.read!(FosBjj.JiuJitsu.Position)
        sub_positions = Ash.read!(FosBjj.JiuJitsu.SubPosition)
        orientations = Ash.read!(FosBjj.JiuJitsu.Orientation)

        form =
          AshPhoenix.Form.for_create(FosBjj.JiuJitsu.Technique, :create,
            as: "technique",
            actor: assigns.current_user
          )
          |> to_form()

        socket
        |> assign(:positions, positions)
        |> assign(:sub_positions, sub_positions)
        |> assign(:orientations, orientations)
        |> assign(:form, form)
        |> assign(:selected_position, nil)
        |> assign(:selected_sub_positions, [])
        |> assign(:selected_orientation, nil)
        |> assign(:child_fields_disabled, true)
        |> assign(:available_orientations, [])
        |> assign(:available_sub_positions, [])
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"technique" => params}, socket) do
    selected_position =
      case Map.get(params, "position") do
        "" -> nil
        nil -> nil
        value -> value
      end

    selected_sub_positions =
      Map.get(params, "sub_positions", []) |> Enum.reject(&(&1 == ""))

    selected_orientation = Map.get(params, "orientation_name")

    {child_fields_disabled, available_orientations} = get_orientation_options(selected_position)

    available_sub_positions =
      get_available_sub_positions(socket.assigns.sub_positions, selected_position)

    valid_sub_position_names = Enum.map(available_sub_positions, & &1.name)

    filtered_selected_sub_positions =
      Enum.filter(selected_sub_positions, &(&1 in valid_sub_position_names))

    updated_params = Map.put(params, "sub_positions", filtered_selected_sub_positions)

    form =
      AshPhoenix.Form.validate(socket.assigns.form, updated_params,
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_position, selected_position)
     |> assign(:selected_sub_positions, filtered_selected_sub_positions)
     |> assign(:selected_orientation, selected_orientation)
     |> assign(:child_fields_disabled, child_fields_disabled)
     |> assign(:available_orientations, available_orientations)
     |> assign(:available_sub_positions, available_sub_positions)}
  end

  @impl true
  def handle_event("save", %{"technique" => params}, socket) do
    selected_position = socket.assigns.selected_position

    selected_sub_positions =
      Map.get(params, "sub_positions", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_positions = if selected_position, do: [selected_position], else: []

    params_with_relationships =
      params
      |> Map.put("positions", selected_positions)
      |> Map.put("sub_positions", selected_sub_positions)

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
    end

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params_with_relationships,
           before_submit: before_submit,
           actor: socket.assigns.current_user
         ) do
      {:ok, technique} ->
        notify_parent({:technique_created, technique})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp get_orientation_options(selected_position) do
    cond do
      is_nil(selected_position) or selected_position == "" -> {true, []}
      selected_position == "standing" -> {true, []}
      selected_position in ["back", "leg_entanglement"] -> {false, ["superior", "inferior"]}
      true -> {false, ["top", "bottom"]}
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
    <div>
      <.form_wrapper for={@form} id="technique-form" phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="space-y-6">
          <.text_field
            field={@form[:name]}
            label="Technique Name"
            placeholder="Enter technique name"
            required
          />

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

          <div class="flex gap-4">
            <.button type="submit" class="btn btn-primary">
              Create Technique
            </.button>
          </div>
        </div>
      </.form_wrapper>
    </div>
    """
  end
end
