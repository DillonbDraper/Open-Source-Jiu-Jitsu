defmodule FosBjjWeb.UserManagementVideoReportsComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.UserMessage
  alias FosBjj.Accounts.UserVideoReport
  alias FosBjj.JiuJitsu.Video
  alias FosBjj.JiuJitsu.VideoNote
  alias Phoenix.LiveView.JS
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:video_report_status_filter, "unresolved")
     |> assign(:video_reports, [])
     |> assign(:show_manage_report_modal, false)
     |> assign(:managed_report, nil)
     |> assign(:manage_report_form, initial_manage_report_form())
     |> assign(:reports_loaded_for_user_id, nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      case socket.assigns.current_user do
        nil ->
          socket
          |> assign(:video_reports, [])
          |> assign(:reports_loaded_for_user_id, nil)

        current_user ->
          if socket.assigns.reports_loaded_for_user_id == current_user.id do
            socket
          else
            reports = list_video_reports(current_user, socket.assigns.video_report_status_filter)

            socket
            |> assign(:video_reports, reports)
            |> assign(:reports_loaded_for_user_id, current_user.id)
          end
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_video_report_status", %{"status" => status}, socket) do
    reports = list_video_reports(socket.assigns.current_user, status)

    {:noreply,
     socket
     |> assign(:video_report_status_filter, status)
     |> assign(:video_reports, reports)}
  end

  @impl true
  def handle_event("open_manage_video_report", %{"id" => id}, socket) do
    report =
      Ash.get!(UserVideoReport, id,
        actor: socket.assigns.current_user,
        load: [:user, :video]
      )

    {:noreply,
     socket
     |> assign(:show_manage_report_modal, true)
     |> assign(:managed_report, report)
     |> assign(:manage_report_form, initial_manage_report_form())}
  end

  @impl true
  def handle_event("close_manage_video_report", _, socket) do
    {:noreply, close_manage_report_modal(socket)}
  end

  @impl true
  def handle_event("update_manage_video_report", params, socket) do
    action = Map.get(params, "action", "keep")
    admin_reason = Map.get(params, "admin_reason", "")

    {:noreply,
     assign(
       socket,
       :manage_report_form,
       to_form(%{"action" => action, "admin_reason" => admin_reason})
     )}
  end

  @impl true
  def handle_event("save_manage_video_report", params, socket) do
    current_user = socket.assigns.current_user
    report = socket.assigns.managed_report
    action = Map.get(params, "action", "keep")
    admin_reason = params |> Map.get("admin_reason", "")

    if admin_reason == "" do
      {:noreply, notify_parent_flash(socket, :danger, "An admin reason is required")}
    else
      case action do
        "delete" ->
          resolve_report_with_delete(socket, report, admin_reason, current_user)

        _ ->
          resolve_report_without_delete(socket, report, admin_reason, current_user)
      end
    end
  end

  defp list_video_reports(actor, status_filter) do
    query =
      UserVideoReport
      |> Ash.Query.load([:user, :video, :reason])
      |> Ash.Query.sort(inserted_at: :desc)

    query =
      case status_filter do
        "resolved" -> Ash.Query.filter(query, resolved == true)
        "unresolved" -> Ash.Query.filter(query, resolved == false)
        _ -> query
      end

    Ash.read!(query, actor: actor)
  end

  defp video_report_reason_label(%{reason: %{label: label}}) when is_binary(label), do: label

  defp video_report_reason_label(%{reason_name: reason_name}) when is_binary(reason_name),
    do: reason_name

  defp video_report_reason_label(_), do: "Other"

  defp video_report_status_label(%{resolved: true, resolution_outcome: :deleted}),
    do: "Resolved - Deleted"

  defp video_report_status_label(%{resolved: true, resolution_outcome: :kept}),
    do: "Resolved - Kept"

  defp video_report_status_label(%{resolved: true}), do: "Resolved"
  defp video_report_status_label(_), do: "Unresolved"

  defp video_report_status_badge_class(%{resolved: true}), do: "badge-success"
  defp video_report_status_badge_class(_), do: "badge-warning"

  defp report_user_display_name(report) do
    case report.user do
      nil -> "Unknown user"
      user -> user.user_name || user.email
    end
  end

  defp report_video_title(report) do
    case report.video do
      nil -> "Video Unavailable"
      video -> video.title
    end
  end

  defp video_available_for_navigation?(report) do
    case report.video do
      %{deleted_at: deleted_at} -> is_nil(deleted_at)
      _ -> false
    end
  end

  defp manage_report_action_value(form) do
    case form[:action].value do
      nil -> "keep"
      value -> value
    end
  end

  defp manage_report_submit_label("delete"), do: "Delete Video"
  defp manage_report_submit_label(_), do: "Resolve Without Deleting"

  defp manage_report_submit_confirmation("delete") do
    "Are you sure you want to soft delete this video? This cannot be undone from this screen."
  end

  defp manage_report_submit_confirmation(_), do: nil

  defp resolve_report_without_delete(socket, report, admin_reason, current_user) do
    case resolve_report(report, admin_reason, :kept, current_user) do
      {:ok, _updated_report} ->
        notify_reporter_resolution(report, admin_reason, :kept, current_user)

        {:noreply,
         socket
         |> close_manage_report_modal()
         |> refresh_video_reports(current_user)
         |> notify_parent_flash(:success, "Report marked as resolved")}

      {:error, _error} ->
        {:noreply, notify_parent_flash(socket, :danger, "Failed to resolve report")}
    end
  end

  defp resolve_report_with_delete(socket, report, admin_reason, current_user) do
    video =
      case report.video do
        nil -> Ash.get!(Video, report.video_id, actor: current_user)
        loaded_video -> loaded_video
      end

    with {:ok, _video} <- soft_delete_video(video, current_user),
         {:ok, _updated_report} <- resolve_report(report, admin_reason, :deleted, current_user) do
      notify_reporter_resolution(report, admin_reason, :deleted, current_user)
      notify_video_references_deleted(video, admin_reason, current_user)

      {:noreply,
       socket
       |> close_manage_report_modal()
       |> refresh_video_reports(current_user)
       |> notify_parent_flash(:success, "Report resolved and video soft deleted")}
    else
      {:error, _error} ->
        {:noreply,
         notify_parent_flash(socket, :danger, "Failed to delete video and resolve report")}
    end
  end

  defp resolve_report(report, admin_reason, outcome, current_user) do
    report
    |> Ash.Changeset.for_update(
      :resolve,
      %{admin_resolution_reason: admin_reason, resolution_outcome: outcome},
      actor: current_user
    )
    |> Ash.update()
  end

  defp soft_delete_video(video, current_user) do
    if is_nil(video.deleted_at) do
      video
      |> Ash.Changeset.for_update(:update, %{deleted_at: DateTime.utc_now()}, actor: current_user)
      |> Ash.update()
    else
      {:ok, video}
    end
  end

  defp notify_reporter_resolution(report, admin_reason, outcome, actor) do
    body =
      case outcome do
        :deleted ->
          "Your report for \"#{report_video_title(report)}\" was reviewed and the video was removed. Reason: #{admin_reason}"

        _ ->
          "Your report for \"#{report_video_title(report)}\" was reviewed and the video was kept. Reason: #{admin_reason}"
      end

    UserMessage
    |> Ash.Changeset.for_create(
      :send_system_message,
      %{body: body, recipient_id: report.user_id},
      actor: actor
    )
    |> Ash.create!()
  end

  defp notify_video_references_deleted(video, admin_reason, actor) do
    user_ids =
      (video_note_user_ids(video.id, actor) ++ message_user_ids(video.id, actor))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    body =
      "A video you referenced, \"#{video.title}\", has been removed and is no longer available.
      We apologize for the inconvenience. \n Reason: #{admin_reason}"

    Enum.each(user_ids, fn recipient_id ->
      UserMessage
      |> Ash.Changeset.for_create(
        :send_system_message,
        %{recipient_id: recipient_id, body: body},
        actor: actor
      )
      |> Ash.create!()
    end)
  end

  defp video_note_user_ids(video_id, actor) do
    VideoNote
    |> Ash.Query.filter(video_id == ^video_id)
    |> Ash.Query.for_read(:read_all)
    |> Ash.read!(actor: actor)
    |> Enum.map(& &1.user_id)
  end

  defp message_user_ids(video_id, actor) do
    UserMessage
    |> Ash.Query.filter(shared_video_id == ^video_id)
    |> Ash.read!(actor: actor)
    |> Enum.flat_map(fn message -> [message.sender_id, message.recipient_id] end)
  end

  defp close_manage_report_modal(socket) do
    socket
    |> assign(:show_manage_report_modal, false)
    |> assign(:managed_report, nil)
    |> assign(:manage_report_form, initial_manage_report_form())
  end

  defp refresh_video_reports(socket, current_user) do
    reports = list_video_reports(current_user, socket.assigns.video_report_status_filter)
    assign(socket, :video_reports, reports)
  end

  defp notify_parent_flash(socket, kind, message) do
    send(self(), {:user_management_video_report_flash, kind, message})
    socket
  end

  defp initial_manage_report_form do
    to_form(%{"action" => "keep", "admin_reason" => ""})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <.h3 class="text-lg font-medium">Video Reports</.h3>
          <.p class="text-sm text-base-content/70">
            Review user-submitted reports for broken or inappropriate videos.
          </.p>
        </div>
      </div>

      <div class="flex justify-end mb-4">
        <form
          phx-change="filter_video_report_status"
          phx-target={@myself}
          class="flex items-center gap-2"
        >
          <label class="text-sm font-medium">Filter by Status:</label>
          <.native_select name="status" size="small" class="min-w-[8rem]">
            <:option value="unresolved" selected={@video_report_status_filter == "unresolved"}>
              Unresolved
            </:option>
            <:option value="resolved" selected={@video_report_status_filter == "resolved"}>
              Resolved
            </:option>
            <:option value="all" selected={@video_report_status_filter == "all"}>All</:option>
          </.native_select>
        </form>
      </div>

      <.table rows={@video_reports}>
        <:col :let={report} label="Reporter">
          <div class="space-y-1">
            <div class="font-medium">{report_user_display_name(report)}</div>
            <div class="text-xs text-base-content/60">User ID: {report.user_id}</div>
          </div>
        </:col>
        <:col :let={report} label="Video">
          <%= if video_available_for_navigation?(report) do %>
            <.link navigate={~p"/videos/#{report.video.id}"} class="link link-primary text-sm">
              {report_video_title(report)}
            </.link>
          <% else %>
            <span class="text-sm text-base-content/70">{report_video_title(report)}</span>
          <% end %>
        </:col>
        <:col :let={report} label="Reason">
          {video_report_reason_label(report)}
        </:col>
        <:col :let={report} label="Message">
          <%= if is_binary(report.message) and String.trim(report.message) != "" do %>
            <.popover
              id={"video-report-message-#{report.id}"}
              width="double_large"
              variant="default"
              color="dark"
              show_delay={300}
            >
              <:trigger class="truncate max-w-xs cursor-help block">{report.message}</:trigger>
              <:content class="text-sm whitespace-pre-line">{report.message}</:content>
            </.popover>
          <% else %>
            <span class="text-xs text-base-content/60">No details provided</span>
          <% end %>
        </:col>
        <:col :let={report} label="Status">
          <span class={["badge", video_report_status_badge_class(report)]}>
            {video_report_status_label(report)}
          </span>
        </:col>
        <:col :let={report} label="Submitted">
          {Calendar.strftime(report.inserted_at, "%b %d, %Y %H:%M %p")}
        </:col>
        <:action :let={report}>
          <div class="flex items-center gap-2">
            <.button
              id={"manage-video-report-#{report.id}"}
              class="btn btn-primary btn-xs"
              phx-click="open_manage_video_report"
              phx-target={@myself}
              phx-value-id={report.id}
            >
              Manage report
            </.button>
            <%= if report.resolved do %>
              <span class="text-green-600" title="Resolved">
                <.icon name="hero-check-badge" class="w-5 h-5" />
              </span>
            <% end %>
          </div>
        </:action>
      </.table>

      <.modal
        :if={@show_manage_report_modal && @managed_report}
        show
        id="manage-video-report-modal"
        size="double_large"
        on_cancel={JS.push("close_manage_video_report", target: @myself)}
      >
        <div class="space-y-4">
          <.h3 class="text-xl font-semibold">Manage Video Report</.h3>

          <div class="bg-base-200 rounded-lg p-3 space-y-1">
            <.p class="text-sm text-base-content/70">Video</.p>
            <.p class="font-medium">{report_video_title(@managed_report)}</.p>
            <.p class="text-sm text-base-content/70">
              Reported by {report_user_display_name(@managed_report)}
            </.p>
          </div>

          <.form
            for={@manage_report_form}
            id="manage-video-report-form"
            phx-change="update_manage_video_report"
            phx-submit="save_manage_video_report"
            phx-target={@myself}
            class="space-y-4"
          >
            <.native_select field={@manage_report_form[:action]} label="Action" required>
              <:option
                value="keep"
                selected={manage_report_action_value(@manage_report_form) == "keep"}
              >
                Mark resolved without deleting
              </:option>
              <:option
                value="delete"
                selected={manage_report_action_value(@manage_report_form) == "delete"}
              >
                Soft delete video and resolve report
              </:option>
            </.native_select>

            <.textarea_field
              id="manage-video-report-admin-reason"
              field={@manage_report_form[:admin_reason]}
              label="Admin reason"
              placeholder="Explain your decision (required)..."
              rows="4"
              required
              class="w-full"
            />

            <div class="flex items-center justify-end gap-2">
              <.button
                type="button"
                variant="transparent"
                color="base"
                phx-click="close_manage_video_report"
                phx-target={@myself}
              >
                Cancel
              </.button>
              <.button
                type="submit"
                variant="default"
                color={
                  if manage_report_action_value(@manage_report_form) == "delete",
                    do: "danger",
                    else: "primary"
                }
                data-confirm={
                  manage_report_submit_confirmation(manage_report_action_value(@manage_report_form))
                }
              >
                {manage_report_submit_label(manage_report_action_value(@manage_report_form))}
              </.button>
            </div>
          </.form>
        </div>
      </.modal>
    </div>
    """
  end
end
