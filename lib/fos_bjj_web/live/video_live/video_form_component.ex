defmodule FosBjjWeb.VideoLive.VideoFormComponent do
  use FosBjjWeb, :live_component
  import FosBjjWeb.Components.Button
  alias FosBjj.JiuJitsu.{InActionStaging, Video}
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
       |> update(:combobox_version, &((&1 || 0) + 1))}
    else
      # Normal update flow
      current_user = assigns.current_user
      video = assigns[:video]

      techniques = Ash.read!(FosBjj.JiuJitsu.Technique)
      grips = Ash.read!(FosBjj.JiuJitsu.Grip)
      video_types = Ash.read!(FosBjj.JiuJitsu.VideoType)

      # Determine if we're creating or updating
      {form, selected_techniques, selected_grips, url_value, selected_video_type} =
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

          {form, selected_techniques, selected_grips, reconstructed_url, video.video_type_name}
        else
          # Creating new video
          form =
            AshPhoenix.Form.for_create(FosBjj.JiuJitsu.Video, :create,
              as: "video",
              actor: current_user
            )
            |> to_form()

          {form, [], [], nil, "instructional"}
        end

      {:ok,
       socket
       |> assign(assigns)
       |> assign(:form, form)
       |> assign(:techniques, techniques)
       |> assign(:grips, grips)
       |> assign(:video_types, video_types)
       |> assign(:selected_techniques, selected_techniques)
       |> assign(:selected_grips, selected_grips)
       |> assign(:selected_video_type, selected_video_type)
       |> assign(:in_action_start_seconds, nil)
       |> assign(:in_action_end_seconds, nil)
       |> assign(:in_action_range_error, nil)
       |> assign(:combobox_version, 0)
       |> assign(:url_value, url_value)}
    end
  end

  @impl true
  def handle_event("validate", %{"video" => params}, socket) do
    # Clean up empty strings from multi-select comboboxes before validation
    # TODO: This shouldn't be necessary
    selected_techniques =
      Map.get(params, "techniques", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_grips =
      Map.get(params, "grips", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    selected_video_type = Map.get(params, "video_type_name", "instructional")

    # Update params with cleaned values before validation
    cleaned_params =
      params
      |> Map.put("techniques", selected_techniques)
      |> Map.put("grips", selected_grips)

    form_params = Map.drop(cleaned_params, ["start_seconds", "end_seconds"])

    form =
      AshPhoenix.Form.validate(socket.assigns.form, form_params,
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_techniques, selected_techniques)
     |> assign(:selected_grips, selected_grips)
     |> assign(:selected_video_type, selected_video_type)
     |> assign(:in_action_start_seconds, Map.get(params, "start_seconds"))
     |> assign(:in_action_end_seconds, Map.get(params, "end_seconds"))
     |> assign(:in_action_range_error, nil)}
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

    if in_action_submission?(cleaned_params, video) do
      case create_in_action_video(
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
    else
      result =
        AshPhoenix.Form.submit(socket.assigns.form,
          params: Map.drop(cleaned_params, ["start_seconds", "end_seconds"]),
          before_submit: before_submit,
          actor: current_user
        )

      case result do
        {:ok, updated_video} ->
          message = if video, do: "Video updated successfully", else: "Video added successfully"

          send(self(), {:video_saved, updated_video})

          {:noreply,
           socket
           |> put_flash(:success, message)}

        {:error, form} ->
          {:noreply,
           socket
           |> put_flash(:danger, "Something went wrong")
           |> assign(form: form)}
      end
    end
  end

  defp in_action_submission?(params, nil), do: Map.get(params, "video_type_name") == "in_action"
  defp in_action_submission?(_params, _video), do: false

  defp create_in_action_video(params, selected_grips, selected_techniques, current_user) do
    with {:ok, source_video_id} <- source_video_id_from_url(Map.get(params, "url")),
         {:ok, start_seconds} <- parse_seconds(Map.get(params, "start_seconds"), "Start time"),
         {:ok, end_seconds} <- parse_seconds(Map.get(params, "end_seconds"), "End time"),
         :ok <- validate_in_action_range(start_seconds, end_seconds) do
      video_params = %{
        video_id: Ecto.UUID.generate(),
        title: Map.get(params, "title"),
        description: Map.get(params, "description"),
        attire: Map.get(params, "attire"),
        thumbnail_url: "https://img.youtube.com/vi/#{source_video_id}/0.jpg",
        video_type_name: "in_action",
        ready: false,
        source_type: :hosted
      }

      FosBjj.Repo.transact(fn ->
        video_changeset =
          Video
          |> Ash.Changeset.for_create(:create, video_params, actor: current_user)
          |> Ash.Changeset.manage_relationship(:grips, selected_grips, type: :append_and_remove)
          |> Ash.Changeset.manage_relationship(:techniques, selected_techniques,
            type: :append_and_remove
          )

        with {:ok, video} <- Ash.create(video_changeset),
             {:ok, _staging} <-
               Ash.create(
                 InActionStaging,
                 %{
                   video_id: video.id,
                   source_url: Map.get(params, "url"),
                   source_video_id: source_video_id,
                   start_seconds: start_seconds,
                   end_seconds: end_seconds
                 },
                 actor: current_user
               ) do
          {:ok, video}
        end
      end)
    end
  end

  defp source_video_id_from_url(url) when is_binary(url) do
    case VideoLinkHelper.extract_id(url) do
      {_source, video_id} when is_binary(video_id) and video_id != "" -> {:ok, video_id}
      _ -> {:error, "Enter a valid YouTube URL for the inAction source video"}
    end
  rescue
    _error -> {:error, "Enter a valid YouTube URL for the inAction source video"}
  end

  defp source_video_id_from_url(_url),
    do: {:error, "Enter a valid YouTube URL for the inAction source video"}

  defp parse_seconds(value, _label) when is_integer(value), do: {:ok, value}

  defp parse_seconds(value, label) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, ""} -> {:ok, seconds}
      _ -> {:error, {:range, "#{label} must be a whole number of seconds"}}
    end
  end

  defp parse_seconds(_value, label),
    do: {:error, {:range, "#{label} must be a whole number of seconds"}}

  defp validate_in_action_range(start_seconds, end_seconds)
       when start_seconds < 0 or end_seconds < 0,
       do: {:error, {:range, "inAction start and end times must be zero or greater"}}

  defp validate_in_action_range(start_seconds, end_seconds) when end_seconds <= start_seconds,
    do: {:error, {:range, "inAction end time must be after the start time"}}

  defp validate_in_action_range(start_seconds, end_seconds)
       when end_seconds - start_seconds > 15,
       do: {:error, {:range, "inAction clips must be 15 seconds or shorter"}}

  defp validate_in_action_range(_start_seconds, _end_seconds), do: :ok

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
            popover="A descriptive, focused list of the techniques covered video without any hype or clickbait,
              ideally with the instructor's name at the end.  I.E. 'Knee/Elbow Mount Escape by Some Famous Guy' "
            required
          />

          <.textarea_field
            field={@form[:description]}
            label="Description"
            placeholder="Description of the video content"
            popover="A detailed description of what you believe are the key points and/or novel insights that the video brings to the table.
              Tell the user why they may want to watch beyond the obvious."
            rows="3"
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

            <.combobox
              id={"video-type-select-#{@id}"}
              field={@form[:video_type_name]}
              label="Video Type"
              value={@form[:video_type_name].value || "instructional"}
              placeholder="Select video type"
              searchable={false}
              size="extra_large"
              popover="Choose Instructional for direct technique instruction, Analysis for studies and breakdowns, or inAction for short staged clips from a source video."
              required
            >
              <:option :for={video_type <- @video_types} value={video_type.name}>
                {video_type.label}
              </:option>
            </.combobox>
          </div>

          <%= if @selected_video_type == "in_action" && is_nil(@video) do %>
            <div class="rounded-xl border border-primary/20 bg-primary/5 p-4 space-y-4">
              <div class="space-y-1">
                <.p size="text-sm" font_weight="font-semibold">inAction Clip Range</.p>
                <.p size="extra_small" class="text-base-content/70">
                  Choose the source video range to stage for clipping. Clips must be 15 seconds or shorter.
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
          <% end %>

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
                popover="Multi select box for techniques in the video.  List all techniques covered in detail in the video, but not techniques that are only touched on.
                  With techniques, more specificity is better.  If a video covers butterfly sweeps in detail from both butterfly and half guard, it is best to include
                  both 'butterfly sweep from butterfly guard' and 'butterfly sweep from half butterfly' both, rather than just one."
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
            id={"grips-select-#{@id}"}
            name="video[grips][]"
            label="Grips"
            multiple={true}
            value={@selected_grips}
            placeholder="Select grips (optional)"
            searchable={true}
            size="extra_large"
            popover="There are near-infinite grips in Jiu-Jitsu and it is very possible the one your are looking for may not be here,
              but do not let them deter you from adding a video"
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
    </div>
    """
  end
end
