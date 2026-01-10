defmodule FosBjjWeb.TechniqueLive.NewTechniqueForm do
  use FosBjjWeb, :live_component
  import FosBjjWeb.Components.Drawer

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if Map.has_key?(socket.assigns, :form) do
      {:ok, socket}
    else
      positions =
        FosBjj.JiuJitsu.Position
        |> Ash.Query.load(:orientations)
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
       |> assign(:selected_orientation, nil)
       |> assign(:selected_sub_position, nil)
       |> assign(:selected_action, nil)
       |> assign(:child_fields_disabled, true)
       |> assign(:available_orientations, [])
       |> assign(:available_sub_positions, [])
       |> assign(:available_actions, [])}
    end
  end

  @impl true
  def handle_event("validate", %{"technique" => params}, socket) do
    # Position is only used for UI filtering, not persisted
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

    selected_orientation =
      Map.get(params, "orientation_name")
      |> case do
        "" -> nil
        nil -> nil
        value -> value
      end

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

    # Filter actions based on position + orientation
    available_actions =
      get_available_actions(final_sub_position, selected_orientation)

    valid_action_names = Enum.map(available_actions, & &1.name)

    final_action =
      if selected_action in valid_action_names do
        selected_action
      else
        nil
      end

    # Only pass fields that exist on the Technique resource
    updated_params =
      params
      |> Map.put("sub_position_name", final_sub_position)
      |> Map.put("action_name", final_action)
      # Remove position as it's not on the resource
      |> Map.delete("position")

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
    current_user = socket.assigns[:current_user]

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: current_user
         ) do
      {:ok, technique} ->
        send(self(), {__MODULE__, {:technique_created, technique}})
        hide_drawer("technique-drawer", "right")
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

  defp get_available_actions(selected_sub_position, selected_orientation) do
    # Actions require both position AND orientation to be selected
    if is_nil(selected_sub_position) or selected_sub_position == "" or
         is_nil(selected_orientation) or selected_orientation == "" do
      []
    else
      import Ecto.Query

      from(apo in "action_sub_position_orientations",
        join: a in "actions",
        on: a.name == apo.action_name,
        where: apo.sub_position_name == ^selected_sub_position,
        where: apo.orientation_name == ^selected_orientation,
        select: %{name: a.name, label: a.label},
        order_by: a.label
      )
      |> FosBjj.Repo.all()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <h2 class="text-2xl font-bold">Add New Technique</h2>
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
            popover="Enter the technique name.  As mentioned in the video form, more specificity is better with techniques.  Knee/Elbow Escape from Side Control and Knee/Elbow
              Escape From Mount count as different moves and should be labeled as such."
            required
          />

          <%!-- Position Select (Not actually part of technique resource) --%>
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

          <p :if={is_nil(@selected_position)} class="text-sm text-gray-500 mt-1">
            Select a position to filter sub-positions
          </p>

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
            Select a position to enable sub-positions
          </p>

          <%!-- Orientation Select.  Brittle, should probably move to loading full struct vs using orientation_name --%>
          <.combobox
            label="Orientation"
            disabled={@child_fields_disabled}
            name="technique[orientation_name]"
            value={@selected_orientation}
            size="extra_large"
            placeholder="Select an orientation"
            id={"orientation-#{@selected_position || "none"}"}
          >
            <:option :for={orientation_name <- @available_orientations} value={orientation_name}>
              {String.capitalize(orientation_name)}
            </:option>
          </.combobox>

          <p :if={@child_fields_disabled} class="text-sm text-gray-500 mt-1">
            Select a position to enable orientation
          </p>

          <%!-- Action Select --%>
          <.combobox
            id={
              "action-select-#{@selected_sub_position || "none"}-#{@selected_orientation || "none"}"
            }
            name="technique[action_name]"
            label="Action"
            value={@selected_action}
            placeholder={
              cond do
                is_nil(@selected_sub_position) -> "Select a sub-position first"
                is_nil(@selected_orientation) -> "Select an orientation first"
                true -> "Select an action"
              end
            }
            disabled={is_nil(@selected_sub_position) or is_nil(@selected_orientation)}
            size="extra_large"
          >
            <:option :for={action <- @available_actions} value={action.name}>
              {action.label}
            </:option>
          </.combobox>

          <p
            :if={is_nil(@selected_sub_position) or is_nil(@selected_orientation)}
            class="text-sm text-gray-500 mt-1"
          >
            Select a sub-position and orientation to enable actions
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
    """
  end
end
