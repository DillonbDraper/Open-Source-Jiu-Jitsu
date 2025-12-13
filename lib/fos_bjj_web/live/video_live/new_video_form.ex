defmodule FosBjjWeb.VideoLive.NewVideoForm do
  use FosBjjWeb, :live_view

  on_mount {AshAuthentication.Phoenix.LiveSession, {:live_user_required, otp_app: :fos_bjj}}

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
     |> assign(:selected_technique_id, nil)
     |> assign(:selected_grips, [])}
  end

  @impl true
  def handle_event("validate", %{"video" => params}, socket) do
    selected_technique_id =
      case Map.get(params, "technique_id") do
        "" -> nil
        nil -> nil
        value when is_binary(value) -> String.to_integer(value)
        value -> value
      end

    selected_grips =
      Map.get(params, "grips", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    form =
      AshPhoenix.Form.validate(socket.assigns.form, params,
        actor: socket.assigns[:current_user]
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_technique_id, selected_technique_id)
     |> assign(:selected_grips, selected_grips)}
  end

  @impl true
  def handle_event("save", %{"video" => params}, socket) do
    selected_grips = socket.assigns.selected_grips
    current_user = socket.assigns[:current_user]

    # Merge relationship data into params
    params_with_relationships = Map.put(params, "grips", selected_grips)

    # Use before_submit to manage relationships manually
    before_submit = fn changeset ->
      Ash.Changeset.manage_relationship(
        changeset,
        :grips,
        selected_grips,
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
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="max-w-2xl mx-auto">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-3xl font-bold">Add New Video</h1>
          <.link navigate={~p"/"} class="btn btn-ghost">
            ← Back
          </.link>
        </div>

        <.form_wrapper for={@form} id="video-form" phx-change="validate" phx-submit="save">
          <div class="space-y-6">
            <%!-- Video URL --%>
            <.url_field
              field={@form[:url]}
              label="Video URL"
              placeholder="https://youtube.com/watch?v=..."
              required
            />

            <%!-- Description --%>
            <.textarea_field
              field={@form[:description]}
              label="Description (Optional)"
              placeholder="Brief description of the video content"
              rows="3"
            />

            <%!-- Attire Radio Buttons --%>
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

            <%!-- Technique Select with Autocomplete --%>
            <.combobox
              id="technique-select"
              name="video[technique_id]"
              label="Technique"
              value={@selected_technique_id && to_string(@selected_technique_id)}
              placeholder="Search for a technique..."
              searchable={true}
              size="extra_large"
              required
            >
              <:option :for={technique <- @techniques} value={to_string(technique.id)}>
                <%= technique.name %>
              </:option>
            </.combobox>

            <%!-- Grips Multi-Select --%>
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
                <%= grip.label %>
              </:option>
            </.combobox>

            <%!-- Submit Buttons --%>
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
    </Layouts.app>
    """
  end
end
