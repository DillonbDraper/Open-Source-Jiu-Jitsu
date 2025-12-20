defmodule FosBjjWeb.TechniqueLive.NewTechniqueForm do
  use FosBjjWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if Map.has_key?(socket.assigns, :form) do
      {:ok, socket}
    else
      positions =
        FosBjj.JiuJitsu.Position
        |> Ash.Query.load([:orientations, :actions])
        |> Ash.read!()

      sub_positions =
        FosBjj.JiuJitsu.SubPosition
        |> Ash.read!()

      orientations = Ash.read!(FosBjj.JiuJitsu.Orientation)
      current_user = socket.assigns[:current_user]

      form =
        AshPhoenix.Form.for_create(FosBjj.JiuJitsu.Technique, :create,
          as: "technique",
          actor: current_user
        )
        |> to_form()

      {:ok,
       socket
       |> assign(:form, form)
       |> assign(:positions, positions)
       |> assign(:sub_positions, sub_positions)
       |> assign(:orientations, orientations)
       |> assign(:selected_position, nil)
       |> assign(:selected_sub_position, nil)
       |> assign(:selected_orientation, nil)
       |> assign(:selected_action, nil)
       |> assign(:child_fields_disabled, true)
       |> assign(:available_orientations, [])
       |> assign(:available_sub_positions, [])
       |> assign(:available_actions, [])}
    end
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

    selected_sub_position =
      Map.get(params, "sub_position_name")
      |> case do
        "" -> nil
        nil -> nil
        value -> value
      end

    selected_action =
      Map.get(params, "action_name")
      |> case do
        "" -> nil
        nil -> nil
        value -> value
      end

    selected_orientation = Map.get(params, "orientation_name")

    {child_fields_disabled, available_orientations} =
      get_orientation_options(selected_position, socket.assigns.positions)

    # Filter sub_positions to only show those belonging to selected position
    available_sub_positions =
      get_available_sub_positions(socket.assigns.sub_positions, selected_position)

    # Remove sub-position if it is no longer valid for the selected position
    valid_sub_position_names = Enum.map(available_sub_positions, & &1.name)

    final_sub_position =
      if selected_sub_position in valid_sub_position_names do
        selected_sub_position
      else
        nil
      end

    # Filter actions to only show those belonging to selected position
    available_actions =
      get_available_actions(socket.assigns.positions, selected_position)

    # Remove action if it is no longer valid for the selected position
    valid_action_names = Enum.map(available_actions, & &1.name)

    final_action =
      if selected_action in valid_action_names do
        selected_action
      else
        nil
      end

    updated_params =
      params
      |> Map.put("sub_position_name", final_sub_position)
      |> Map.put("action_name", final_action)

    form =
      AshPhoenix.Form.validate(socket.assigns.form, updated_params,
        actor: socket.assigns[:current_user]
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_position, selected_position)
     |> assign(:selected_sub_position, final_sub_position)
     |> assign(:selected_orientation, selected_orientation)
     |> assign(:selected_action, final_action)
     |> assign(:child_fields_disabled, child_fields_disabled)
     |> assign(:available_orientations, available_orientations)
     |> assign(:available_sub_positions, available_sub_positions)
     |> assign(:available_actions, available_actions)}
  end

  @impl true
  def handle_event("save", %{"technique" => params}, socket) do
    selected_position = socket.assigns.selected_position
    current_user = socket.assigns[:current_user]

    # Wrap single position in a list for the relationship
    selected_positions = if selected_position, do: [selected_position], else: []

    # Merge relationship data into params
    params_with_relationships =
      params
      |> Map.put("positions", selected_positions)

    # Use before_submit to manage relationships manually
    before_submit = fn changeset ->
      changeset
      |> Ash.Changeset.manage_relationship(:positions, selected_positions,
        type: :append_and_remove
      )
    end

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params_with_relationships,
           before_submit: before_submit,
           actor: current_user
         ) do
      {:ok, technique} ->
        send(self(), {__MODULE__, {:technique_created, technique}})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp get_orientation_options(selected_position, positions) do
    if is_nil(selected_position) or selected_position == "" do
      {true, []}
    else
      position = Enum.find(positions, &(&1.name == selected_position))

      if position do
        orientations =
          position.orientations
          |> Enum.map(& &1.name)

        {false, orientations}
      else
        {true, []}
      end
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

  defp get_available_actions(all_positions, selected_position) do
    if is_nil(selected_position) or selected_position == "" do
      []
    else
      position = Enum.find(all_positions, fn p -> p.name == selected_position end)

      if position do
        position.actions
      else
        []
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
    <div>
      <div class="mb-6">
        <h1 class="text-3xl font-bold">Add New Technique</h1>
      </div>

      <.form_wrapper
        for={@form}
        id="technique-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
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
              {position.label}
            </:option>
          </.combobox>

          <%!-- Sub-Position Single Select --%>
          <.combobox
            id={"sub-position-select-#{@selected_position || "none"}"}
            name="technique[sub_position_name]"
            label="Sub-Position"
            value={@selected_sub_position}
            placeholder={
              if is_nil(@selected_position),
                do: "Select a position first",
                else: "Select a sub-position"
            }
            disabled={is_nil(@selected_position)}
            size="extra_large"
          >
            <:option :for={sub_position <- @available_sub_positions} value={sub_position.name}>
              {sub_position.label}
            </:option>
          </.combobox>

          <p :if={@child_fields_disabled} class="text-sm text-gray-500 mt-1">
            Select a position to enable Subpositions
          </p>

          <%!-- Action Select --%>
          <.combobox
            id={"action-select-#{@selected_position || "none"}"}
            name="technique[action_name]"
            label="Action"
            value={@selected_action}
            placeholder={
              if is_nil(@selected_position), do: "Select a position first", else: "Select an action"
            }
            disabled={is_nil(@selected_position)}
            size="extra_large"
          >
            <:option :for={action <- @available_actions} value={action.name}>
              {action.label}
            </:option>
          </.combobox>

          <p :if={is_nil(@selected_position)} class="text-sm text-gray-500 mt-1">
            Select a position to enable Actions
          </p>

          <%!-- Orientation Select --%>
          <.native_select
            field={@form[:orientation_name]}
            label="Orientation"
            disabled={@child_fields_disabled}
          >
            <option value="">Select orientation</option>
            <:option :for={orientation_name <- @available_orientations} value={orientation_name}>
              {@orientations
              |> Enum.find(&(&1.name == orientation_name))
              |> then(& &1.label)}
            </:option>
          </.native_select>

          <p :if={@child_fields_disabled} class="text-sm text-gray-500 mt-1">
            Select a position to enable Orientation
          </p>

          <%!-- Submit Buttons --%>
          <div class="flex gap-4">
            <.button type="submit" class="btn btn-primary">
              Create Technique
            </.button>
          </div>
        </div>
        </.form_wrapper>
      </div>
    </Layouts.app>
    """
  end
end
