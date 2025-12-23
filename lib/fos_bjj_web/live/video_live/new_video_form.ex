defmodule FosBjjWeb.VideoLive.NewVideoForm do
  use FosBjjWeb, :live_view
  import FosBjjWeb.Components.Drawer
  alias FosBjjWeb.TechniqueLive.NewTechniqueForm

  on_mount({AshAuthentication.Phoenix.LiveSession, {:live_user_required, otp_app: :fos_bjj}})

  @impl true
  def mount(_params, _session, socket) do
    techniques = Ash.read!(FosBjj.JiuJitsu.Technique)
    grips = Ash.read!(FosBjj.JiuJitsu.Grip)
    current_user = socket.assigns[:current_user]

    form =
      AshPhoenix.Form.for_create(FosBjj.JiuJitsu.Video, :create,
        as: "video",
        actor: current_user
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:techniques, techniques)
     |> assign(:grips, grips)
     |> assign(:selected_techniques, [])
     |> assign(:selected_grips, [])
     |> assign(:combobox_version, 0)
     |> assign(:show_drawer, false)}
  end

  @impl true
  def handle_event("validate", %{"video" => params}, socket) do
    selected_techniques =
      Map.get(params, "techniques", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_grips =
      Map.get(params, "grips", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    form =
      AshPhoenix.Form.validate(socket.assigns.form, params, actor: socket.assigns[:current_user])

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
    current_user = socket.assigns[:current_user]

    params_with_relationships =
      Map.put(params, "grips", selected_grips)
      |> Map.put("techniques", selected_techniques)

    # Use before_submit to manage relationships manually
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

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params_with_relationships,
           before_submit: before_submit,
           actor: current_user
         ) do
      {:ok, _video} ->
        {:noreply,
         socket
         |> put_flash(:info, "Video added successfully")
         |> push_navigate(to: ~p"/")}

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
  def handle_info({NewTechniqueForm, {:technique_created, technique}}, socket) do
    current_technique_ids =
      socket.assigns.form.params
      |> Map.get("techniques", [])
      |> List.wrap()

    new_technique_ids = [to_string(technique.id) | current_technique_ids]

    params =
      socket.assigns.form.params
      |> Map.put("techniques", new_technique_ids)

    form =
      AshPhoenix.Form.validate(socket.assigns.form, params, actor: socket.assigns[:current_user])

    {:noreply,
     socket
     |> assign(:techniques, [technique | socket.assigns.techniques])
     |> assign(:selected_techniques, new_technique_ids)
     |> assign(:form, form)
     |> assign(:show_drawer, false)
     |> update(:combobox_version, &((&1 || 0) + 1))
     |> put_flash(:info, "Technique created successfully")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="max-w-2xl mx-auto">
        <.flash kind={:info} title="Success" flash={@flash} />
        <.flash kind={:error} title="Error" flash={@flash} />
        <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">Add New Video</h1>
          <.link navigate={~p"/"} class="btn btn-ghost">
            ← Back
          </.link>
        </div>

        <.form_wrapper for={@form} id="video-form" phx-change="validate" phx-submit="save">
          <div class="space-y-6">
            <.url_field
              field={@form[:url]}
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
                  id={"technique-select-#{@combobox_version || 0}"}
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
                    JS.push("open_drawer")
                    |> show_drawer("technique-drawer", "right")
                  }
                  title="Add New Technique"
                >
                  Add New Technique (If Not Found)
                </.button>
              </div>
            </div>

            <.combobox
              id="grips-select"
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
                Add Video
              </.button>
              <.button type="button" class="btn btn-ghost" phx-click={JS.navigate(~p"/")}>
                Cancel
              </.button>
            </div>
          </div>
        </.form_wrapper>
      </div>

      <.drawer
        id="technique-drawer"
        show={@show_drawer}
        on_hide={JS.push("close_drawer") |> hide_drawer("technique-drawer", "right")}
        position="right"
        title="Add New Technique"
      >
        <.live_component
          :if={@show_drawer}
          module={NewTechniqueForm}
          id="new-technique-form"
          current_user={@current_user}
        />
      </.drawer>
    </Layouts.app>
    """
  end
end
