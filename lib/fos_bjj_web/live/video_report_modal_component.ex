defmodule FosBjjWeb.VideoReportModalComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.VideoReportReason
  alias FosBjj.Accounts.UserVideoReport

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:video_report_reasons, list_video_report_reasons())
     |> assign(:show_modal, false)
     |> assign(:report_form, initial_report_form())}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("open_modal", _, socket) do
    if socket.assigns.current_user do
      {:noreply,
       socket
       |> assign(:show_modal, true)
       |> assign(:report_form, initial_report_form())}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:report_form, initial_report_form())}
  end

  @impl true
  def handle_event("update_form", params, socket) do
    reason_name = Map.get(params, "reason_name", "")
    message = Map.get(params, "message", "")

    {:noreply,
     assign(socket, :report_form, to_form(%{"reason_name" => reason_name, "message" => message}))}
  end

  @impl true
  def handle_event("submit", params, socket) do
    user = socket.assigns.current_user
    video = socket.assigns.video
    reason_name_param = Map.get(params, "reason_name", "")
    message = Map.get(params, "message", "")

    cond do
      is_nil(user) ->
        {:noreply,
         socket
         |> notify_parent_flash(:danger, "You must be signed in to report videos")}

      is_nil(video) ->
        {:noreply, socket |> notify_parent_flash(:danger, "Video not found")}

      !valid_reason?(socket.assigns.video_report_reasons, reason_name_param) ->
        {:noreply, socket |> notify_parent_flash(:danger, "Please select a reason")}

      true ->
        submit_report(socket, user, video, reason_name_param, message)
    end
  end

  defp submit_report(socket, user, video, reason_name, message) do
    case submit_video_report(user, video, reason_name, message) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:show_modal, false)
         |> assign(:report_form, initial_report_form())
         |> notify_parent_flash(
           :success,
           "Thanks for your report. Our team will review this video."
         )}

      {:error, _error} ->
        {:noreply,
         socket
         |> notify_parent_flash(:danger, "We could not submit your report. Please try again.")}
    end
  end

  defp notify_parent_flash(socket, kind, message) do
    send(self(), {:video_report_flash, kind, message})
    socket
  end

  defp submit_video_report(user, video, reason_name, message) do
    cleaned_message =
      case message do
        text when is_binary(text) ->
          trimmed = String.trim(text)
          if trimmed == "", do: nil, else: trimmed

        _ ->
          nil
      end

    UserVideoReport
    |> Ash.Changeset.for_create(
      :submit,
      %{reason_name: reason_name, message: cleaned_message, video_id: video.id},
      actor: user
    )
    |> Ash.create()
  end

  defp initial_report_form do
    to_form(%{"reason_name" => "", "message" => ""})
  end

  defp valid_reason?(video_report_reasons, reason_name) do
    Enum.any?(video_report_reasons, &(&1.name == reason_name))
  end

  defp list_video_report_reasons do
    VideoReportReason
    |> Ash.Query.sort(label: :asc)
    |> Ash.read!()
  end

  defp blank_reason?(nil), do: true
  defp blank_reason?(""), do: true
  defp blank_reason?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="contents">
      <%= if @current_user && @video do %>
        <.tooltip id="report-video-tooltip" position="left" color="dark">
          <:trigger>
            <.button
              id="report-video-button"
              type="button"
              phx-click="open_modal"
              phx-target={@myself}
              variant="default"
              color="danger"
              size="small"
              circle
              icon="hero-flag"
              icon_class="w-5 h-5"
            />
          </:trigger>
          <:content>Report this video</:content>
        </.tooltip>

        <.modal
          :if={@show_modal}
          show
          id="report-video-modal"
          size="large"
          on_cancel={JS.push("close_modal", target: @myself)}
        >
          <div class="space-y-4">
            <.h3 class="text-xl font-semibold">Report Video</.h3>

            <div class="bg-base-200 rounded-lg p-3">
              <.p class="text-sm text-base-content/70">Reporting:</.p>
              <.p class="font-medium">{@video.title}</.p>
            </div>

            <.form
              for={@report_form}
              id="report-video-form"
              phx-change="update_form"
              phx-submit="submit"
              phx-target={@myself}
              class="space-y-4"
            >
              <.native_select field={@report_form[:reason_name]} label="Reason" required>
                <:option
                  value=""
                  selected={blank_reason?(@report_form[:reason_name].value)}
                  disabled="disabled"
                >
                  Select a reason
                </:option>
                <:option
                  :for={reason <- @video_report_reasons}
                  value={reason.name}
                  selected={reason.name == @report_form[:reason_name].value}
                >
                  {reason.label}
                </:option>
              </.native_select>

              <.textarea_field
                id={"#{@id}-report-message"}
                field={@report_form[:message]}
                label="Details (optional)"
                placeholder="Share any additional details..."
                rows="3"
                class="w-full"
              />

              <div class="flex justify-end gap-2">
                <.button
                  type="button"
                  phx-click="close_modal"
                  phx-target={@myself}
                  variant="transparent"
                  color="base"
                >
                  Cancel
                </.button>
                <.button
                  type="submit"
                  variant="default"
                  color="danger"
                  icon="hero-flag"
                  icon_class="w-4 h-4"
                >
                  Submit Report
                </.button>
              </div>
            </.form>
          </div>
        </.modal>
      <% end %>
    </div>
    """
  end
end
