defmodule FosBjjWeb.VideoLive.VideoFormComponent do
  use FosBjjWeb, :live_component
  import FosBjjWeb.Components.Button
  alias FosBjjWeb.TechniqueLive.NewTechniqueForm
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    # Special handling for technique_created action
    if assigns[:action] == :technique_created && socket.assigns[:form] do
      technique = assigns[:technique]

      current_technique_ids =
        socket.assigns.form.params
        |> Map.get("techniques", [])
        |> List.wrap()

      new_technique_ids = [to_string(technique.id) | current_technique_ids]

      params =
        socket.assigns.form.params
        |> Map.put("techniques", new_technique_ids)

      form =
        AshPhoenix.Form.validate(socket.assigns.form, params, actor: socket.assigns.current_user)

      {:ok,
       socket
       |> assign(:techniques, [technique | socket.assigns.techniques])
       |> assign(:selected_techniques, new_technique_ids)
       |> assign(:form, form)
       |> assign(:show_drawer, false)
       |> update(:combobox_version, &((&1 || 0) + 1))}
    else
      # Normal update flow
      current_user = assigns.current_user
      video = assigns[:video]

      techniques = Ash.read!(FosBjj.JiuJitsu.Technique)
      grips = Ash.read!(FosBjj.JiuJitsu.Grip)

      # Determine if we're creating or updating
      {form, selected_techniques, selected_grips, url_value} =
        if video do
          # Editing existing video
          video = Ash.load!(video, [:techniques, :grips])

          form =
            AshPhoenix.Form.for_update(video, :update,
              as: "video",
              actor: current_user
            )
            |> to_form()

          # Reconstruct the full YouTube URL from the video_id for display in the form
          reconstructed_url = "https://www.youtube.com/watch?v=#{video.video_id}"

          selected_techniques = Enum.map(video.techniques, &to_string(&1.id))
          selected_grips = Enum.map(video.grips, & &1.name)

          {form, selected_techniques, selected_grips, reconstructed_url}
        else
          # Creating new video
          form =
            AshPhoenix.Form.for_create(FosBjj.JiuJitsu.Video, :create,
              as: "video",
              actor: current_user
            )
            |> to_form()

          {form, [], [], nil}
        end

      {:ok,
       socket
       |> assign(assigns)
       |> assign(:form, form)
       |> assign(:techniques, techniques)
       |> assign(:grips, grips)
       |> assign(:selected_techniques, selected_techniques)
       |> assign(:selected_grips, selected_grips)
       |> assign(:combobox_version, 0)
       |> assign(:show_drawer, false)
       |> assign(:url_value, url_value)}
    end
  end

  @impl true
  def handle_event("validate", %{"video" => params}, socket) do
    # Clean up empty strings from multi-select comboboxes before validation
    selected_techniques =
      Map.get(params, "techniques", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_grips =
      Map.get(params, "grips", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    # Update params with cleaned values before validation
    cleaned_params =
      params
      |> Map.put("techniques", selected_techniques)
      |> Map.put("grips", selected_grips)

    form =
      AshPhoenix.Form.validate(socket.assigns.form, cleaned_params,
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_techniques, selected_techniques)
     |> assign(:selected_grips, selected_grips)}
  end

  @impl true
  def handle_event("save", %{"video" => params}, socket) do
    selected_grips = socket.assigns.selected_grips
    selected_techniques = socket.assigns.selected_techniques
    current_user = socket.assigns.current_user
    video = socket.assigns[:video]

    cleaned_params =
      params
      |> Map.put("grips", selected_grips)
      |> Map.put("techniques", selected_techniques)

    before_submit = fn changeset ->
      Ash.Changeset.manage_relationship(
        changeset,
        :grips,
        selected_grips,
        type: :append_and_remove
      )
      |> Ash.Changeset.manage_relationship(:techniques, selected_techniques,
        type: :append_and_remove
      )
    end

    result =
      AshPhoenix.Form.submit(socket.assigns.form,
        params: cleaned_params,
        before_submit: before_submit,
        actor: current_user
      )

    case result do
      {:ok, updated_video} ->
        message = if video, do: "Video updated successfully", else: "Video added successfully"

        send(self(), {:video_saved, updated_video})

        {:noreply,
         socket
         |> put_flash(:info, message)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong")
         |> assign(form: form)}
    end
  end

  @impl true
  def handle_event("open_drawer", _, socket) do
    {:noreply, assign(socket, :show_drawer, true)}
  end

  @impl true
  def handle_event("close_drawer", _, socket) do
    {:noreply, assign(socket, :show_drawer, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form_wrapper
        for={@form}
        id={"video-form-#{@id}"}
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <div class="space-y-6">
          <.url_field
            name="video[url]"
            value={@url_value || @form.params["url"] || ""}
            label="Video URL"
            placeholder="https://youtube.com/watch?v=..."
            required
          />

          <.text_field
            field={@form[:title]}
            label="Video Title"
            placeholder="Title of video"
            required
          />

          <.textarea_field
            field={@form[:description]}
            label="Description (Optional)"
            placeholder="Brief description of the video content"
            rows="3"
          />

          <div class="space-y-2">
            <label class="text-sm font-semibold">Attire *</label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name={@form[:attire].name}
                  value="gi"
                  checked={to_string(@form[:attire].value) == "gi"}
                  class="radio"
                  required
                />
                <span>Gi</span>
              </label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name={@form[:attire].name}
                  value="no_gi"
                  checked={to_string(@form[:attire].value) == "no_gi"}
                  class="radio"
                  required
                />
                <span>No-Gi</span>
              </label>
            </div>
          </div>

          <%!-- Technique Select/Add --%>
          <div class="grid grid-cols-3 gap-2 items-end">
            <div class="col-span-2">
              <.combobox
                id={"technique-select-#{@id}-#{@combobox_version || 0}"}
                name="video[techniques][]"
                label="Technique"
                value={@selected_techniques}
                placeholder="Search for a technique..."
                searchable={true}
                multiple={true}
                size="extra_large"
                required
              >
                <:option :for={technique <- @techniques} value={to_string(technique.id)}>
                  {technique.name}
                </:option>
              </.combobox>
            </div>
            <div class="col-span-1">
              <.button
                type="button"
                class="w-full"
                phx-click={
                  JS.push("open_drawer", target: @myself)
                  |> show_drawer("technique-drawer-#{@id}", "right")
                }
                title="Add New Technique"
              >
                Add New Technique (If Not Found)
              </.button>
            </div>
          </div>

          <.combobox
            id={"grips-select-#{@id}"}
            name="video[grips][]"
            label="Grips"
            multiple={true}
            value={@selected_grips}
            placeholder="Select grips (optional)"
            searchable={true}
            size="extra_large"
          >
            <:option :for={grip <- @grips} value={grip.name}>
              {grip.label}
            </:option>
          </.combobox>

          <div class="flex gap-4">
            <.button type="submit" class="btn btn-primary">
              {if @video, do: "Update Video", else: "Add Video"}
            </.button>
            <.button
              type="button"
              class="btn btn-ghost"
              phx-click={@on_cancel || JS.navigate(~p"/")}
            >
              Cancel
            </.button>
          </div>
        </div>
      </.form_wrapper>

      <.drawer
        id={"technique-drawer-#{@id}"}
        show={@show_drawer}
        on_hide={
          JS.push("close_drawer", target: @myself)
          |> hide_drawer("technique-drawer-#{@id}", "right")
        }
        position="right"
      >
        <.live_component
          :if={@show_drawer}
          module={NewTechniqueForm}
          id={"new-technique-form-#{@id}"}
          current_user={@current_user}
          show_drawer={@show_drawer}
        />
      </.drawer>
    </div>
    """
  end
end
