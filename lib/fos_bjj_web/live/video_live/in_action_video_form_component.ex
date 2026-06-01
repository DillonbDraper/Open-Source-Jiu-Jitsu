defmodule FosBjjWeb.VideoLive.InActionVideoFormComponent do
  use FosBjjWeb, :live_component

  import FosBjjWeb.Components.Button

  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
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
        |> Map.put("video_type_name", "in_action")

      form = to_form(params, as: "video")

      {:ok,
       socket
       |> assign(:techniques, [technique | socket.assigns.techniques])
       |> assign(:selected_techniques, new_technique_ids)
       |> assign(:form, form)
       |> update(:combobox_version, &((&1 || 0) + 1))}
    else
      techniques = Ash.read!(FosBjj.JiuJitsu.Technique)
      grips = Ash.read!(FosBjj.JiuJitsu.Grip)

      form =
        %{
          "url" => "",
          "title" => "",
          "attire" => nil,
          "start_seconds" => "",
          "end_seconds" => "",
          "techniques" => [],
          "grips" => [],
          "video_type_name" => "in_action"
        }
        |> to_form(as: "video")

      {:ok,
       socket
       |> assign(assigns)
       |> assign(:form, form)
       |> assign(:techniques, techniques)
       |> assign(:grips, grips)
       |> assign(:selected_techniques, [])
       |> assign(:selected_grips, [])
       |> assign(:in_action_start_seconds, nil)
       |> assign(:in_action_end_seconds, nil)
       |> assign(:in_action_range_error, nil)
       |> assign(:combobox_version, 0)
       |> assign(:url_value, nil)}
    end
  end

  @impl true
  def handle_event("validate", %{"video" => params}, socket) do
    selected_techniques =
      Map.get(params, "techniques", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_grips =
      Map.get(params, "grips", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    cleaned_params =
      params
      |> Map.put("techniques", selected_techniques)
      |> Map.put("grips", selected_grips)
      |> Map.put("video_type_name", "in_action")

    form = to_form(cleaned_params, as: "video")

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_techniques, selected_techniques)
     |> assign(:selected_grips, selected_grips)
     |> assign(:in_action_start_seconds, Map.get(params, "start_seconds"))
     |> assign(:in_action_end_seconds, Map.get(params, "end_seconds"))
     |> assign(:in_action_range_error, nil)}
  end

  @impl true
  def handle_event("save", %{"video" => params}, socket) do
    selected_grips = socket.assigns.selected_grips
    selected_techniques = socket.assigns.selected_techniques
    current_user = socket.assigns.current_user

    cleaned_params =
      params
      |> Map.put("grips", selected_grips)
      |> Map.put("techniques", selected_techniques)
      |> Map.put("video_type_name", "in_action")

    case FosBjj.JiuJitsu.create_in_action_video(
           cleaned_params,
           selected_grips,
           selected_techniques,
           current_user
         ) do
      {:ok, staged_video} ->
        send(self(), {:video_saved, staged_video})

        {:noreply,
         socket
         |> put_flash(:success, "inAction video staged successfully")}

      {:error, {:range, message}} ->
        {:noreply,
         socket
         |> put_flash(:danger, message)
         |> assign(:in_action_range_error, message)}

      {:error, message} when is_binary(message) ->
        {:noreply,
         socket
         |> put_flash(:danger, message)}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:danger, "Something went wrong")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form_wrapper
        for={@form}
        id={"in-action-video-form-#{@id}"}
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
        novalidate
      >
        <div class="space-y-6">
          <div class="rounded-xl border border-primary/20 bg-primary/5 p-4 space-y-1">
            <.p size="text-sm" font_weight="font-semibold">inAction Clip</.p>
            <.p size="extra_small" class="text-base-content/70">
              Stage a short hosted clip from a source YouTube video. Clips must be 15 seconds or shorter.
            </.p>
          </div>

          <.url_field
            name="video[url]"
            value={@url_value || @form.params["url"] || ""}
            label="Source Video URL"
            placeholder="https://youtube.com/watch?v=..."
            required
          />

          <.text_field
            field={@form[:title]}
            label="Video Title"
            placeholder="Title of inAction clip"
            popover="A concise title for the staged clip. Keep it focused on the movement or exchange shown."
            required
          />

          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div class="space-y-2">
              <.p size="text-sm" font_weight="font-semibold">Attire *</.p>
              <.group_radio
                field={@form[:attire]}
                variation="horizontal"
                space="medium"
                class="flex gap-4"
                required
              >
                <:radio value="gi" checked={to_string(@form[:attire].value) == "gi"}>Gi</:radio>
                <:radio value="no_gi" checked={to_string(@form[:attire].value) == "no_gi"}>
                  No-Gi
                </:radio>
              </.group_radio>
            </div>
          </div>

          <div class="rounded-xl border border-base-300/80 bg-base-100 p-4 space-y-4">
            <div class="space-y-1">
              <.p size="text-sm" font_weight="font-semibold">Clip Range</.p>
              <.p size="extra_small" class="text-base-content/70">
                Enter the source video timestamps in seconds.
              </.p>
            </div>

            <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
              <.number_field
                id={"in-action-start-seconds-#{@id}"}
                name="video[start_seconds]"
                value={@in_action_start_seconds || ""}
                label="Start time (seconds)"
                min="0"
                step="1"
                required
              />

              <.number_field
                id={"in-action-end-seconds-#{@id}"}
                name="video[end_seconds]"
                value={@in_action_end_seconds || ""}
                label="End time (seconds)"
                min="0"
                step="1"
                required
              />
            </div>

            <.p :if={@in_action_range_error} size="extra_small" class="text-danger">
              {@in_action_range_error}
            </.p>
          </div>

          <div class="grid grid-cols-3 gap-2 items-end">
            <div class="col-span-2">
              <.combobox
                id={"in-action-technique-select-#{@id}-#{@combobox_version || 0}"}
                name="video[techniques][]"
                label="Technique"
                value={@selected_techniques}
                placeholder="Search for a technique..."
                searchable={true}
                multiple={true}
                size="extra_large"
                popover="Select the primary techniques visible in this inAction clip."
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
                phx-click="open_technique_drawer"
                title="Add New Technique"
              >
                Add New Technique (If Not Found)
              </.button>
            </div>
          </div>

          <.combobox
            id={"in-action-grips-select-#{@id}"}
            name="video[grips][]"
            label="Grips"
            multiple={true}
            value={@selected_grips}
            placeholder="Select grips (optional)"
            searchable={true}
            size="extra_large"
            popover="Select grips visible in the clip when relevant."
          >
            <:option :for={grip <- @grips} value={grip.name}>
              {grip.label}
            </:option>
          </.combobox>

          <div class="flex gap-4">
            <.button type="submit" class="btn btn-primary">
              Stage inAction Video
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
    </div>
    """
  end
end
