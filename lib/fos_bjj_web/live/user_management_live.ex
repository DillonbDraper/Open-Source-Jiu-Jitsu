defmodule FosBjjWeb.UserManagementLive do
  use FosBjjWeb, :live_view
  alias FosBjj.Accounts.CoachApplication
  alias FosBjj.Accounts.User
  alias FosBjj.Accounts.UserMessage
  require Ash.Query

  on_mount {FosBjjWeb.LiveUserAuth, :live_admin_required}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    users = Ash.read!(User, actor: current_user)
    coach_applications = list_coach_applications(current_user)

    {:ok,
     socket
     |> assign(:page_title, "User Management")
     |> assign(:users, users)
     |> assign(:role_filter, "all")
     |> assign(:editing_user, nil)
     |> assign(:target_role, nil)
     |> assign(:coach_applications, coach_applications)}
  end

  @impl true
  def handle_event("filter_role", %{"role" => role}, socket) do
    users = list_users(socket.assigns.current_user, role)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:role_filter, role)}
  end

  @impl true
  def handle_event("edit_role", %{"id" => id}, socket) do
    user = Ash.get!(User, id, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:editing_user, user)
     |> assign(:target_role, user.role_name)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing_user, nil)}
  end

  @impl true
  def handle_event("validate_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, :target_role, role)}
  end

  @impl true
  def handle_event("save_role", %{"role" => role}, socket) do
    case socket.assigns.editing_user
         |> Ash.Changeset.for_update(:update_role, %{role: role},
           actor: socket.assigns.current_user
         )
         |> Ash.update() do
      {:ok, _user} ->
        users = list_users(socket.assigns.current_user, socket.assigns.role_filter)

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:editing_user, nil)
         |> put_flash(:info, "User role updated successfully.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to update role.")}
    end
  end

  @impl true
  def handle_event("approve_coach_application", %{"id" => id}, socket) do
    update_coach_application_status(socket, id, :approved)
  end

  @impl true
  def handle_event("deny_coach_application", %{"id" => id}, socket) do
    update_coach_application_status(socket, id, :denied)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_width current_user={assigns[:current_user]}>
      <div class="space-y-6">
        <header>
          <.h1 class="text-3xl font-extrabold tracking-tight text-base-content">
            {@page_title}
          </.h1>
          <.p class="mt-2 text-lg text-base-content/70">
            View and manage system users.
          </.p>
        </header>

        <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
          <div class="flex justify-end mb-4">
            <form phx-change="filter_role" class="flex items-center gap-2">
              <label class="text-sm font-medium">Filter by Role:</label>
              <select name="role" class="select select-bordered select-sm">
                <option value="all" selected={@role_filter == "all"}>All Roles</option>
                <option value="user" selected={@role_filter == "user"}>User</option>
                <option value="coach" selected={@role_filter == "coach"}>Coach</option>
                <option value="admin" selected={@role_filter == "admin"}>Admin</option>
              </select>
            </form>
          </div>

          <.table rows={@users}>
            <:col :let={user} label="Email">{user.email}</:col>
            <:col :let={user} label="Confirmed At">{user.confirmed_at}</:col>
            <:col :let={user} label="Role">
              <%= if @editing_user && @editing_user.id == user.id do %>
                <form
                  phx-submit="save_role"
                  phx-change="validate_role"
                  class="flex items-center gap-2"
                >
                  <select name="role" class="select select-bordered select-xs">
                    <option value="student" selected={@target_role == "student"}>Student</option>
                    <option value="coach" selected={@target_role == "coach"}>Coach</option>
                    <option value="admin" selected={@target_role == "admin"}>Admin</option>
                  </select>
                  <.button
                    type="submit"
                    class="btn btn-primary btn-xs"
                    data-confirm={role_change_warning(@editing_user.role_name, @target_role)}
                  >
                    Save
                  </.button>
                  <.button type="button" phx-click="cancel_edit" class="btn btn-ghost btn-xs">
                    Cancel
                  </.button>
                </form>
              <% else %>
                <div class="flex items-center gap-2">
                  <span class={"badge " <> role_badge_class(user.role_name)}>
                    {String.capitalize(user.role_name)}
                  </span>
                  <.button
                    class="btn btn-ghost btn-xs"
                    phx-click="edit_role"
                    phx-value-id={user.id}
                    aria-label="Edit Role"
                    title="Edit Video"
                  >
                    <.icon name="hero-pencil-solid" class="w-4 h-4" />
                  </.button>
                </div>
              <% end %>
            </:col>
          </.table>
        </div>

        <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
          <div class="flex items-center justify-between mb-4">
            <div>
              <.h3 class="text-lg font-medium">Coach Applications</.h3>
              <.p class="text-sm text-base-content/70">
                Review and approve applications for coach access.
              </.p>
            </div>
          </div>

          <.table rows={@coach_applications}>
            <:col :let={application} label="Applicant">
              <div class="space-y-1">
                <div class="font-medium">{application.user.email}</div>
                <div class="text-xs text-base-content/60">User ID: {application.user_id}</div>
              </div>
            </:col>
            <:col :let={application} label="Message">
              <.popover
                id={"coach-app-body-#{application.id}"}
                width="double_large"
                variant="default"
                color="dark"
                show_delay={300}
              >
                <:trigger class="truncate max-w-xs cursor-help block">
                  {application.body}
                </:trigger>
                <:content class="text-sm whitespace-pre-line">
                  {application.body}
                </:content>
              </.popover>
            </:col>
            <:col :let={application} label="Status">
              <span class={"badge " <> coach_application_badge_class(application.status)}>
                {coach_application_status_label(application.status)}
              </span>
            </:col>
            <:col :let={application} label="Submitted">
              {Calendar.strftime(application.inserted_at, "%b %d, %Y %H:%M %p")}
            </:col>
            <:action :let={application}>
              <div class="flex gap-2">
                <.button
                  class="btn btn-success btn-xs"
                  phx-click="approve_coach_application"
                  phx-value-id={application.id}
                  disabled={!coach_application_pending?(application.status)}
                >
                  Approve
                </.button>
                <.button
                  class="btn btn-error btn-xs"
                  phx-click="deny_coach_application"
                  phx-value-id={application.id}
                  disabled={!coach_application_pending?(application.status)}
                >
                  Deny
                </.button>
              </div>
            </:action>
          </.table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp role_badge_class(:admin), do: "badge-secondary"
  defp role_badge_class(:coach), do: "badge-primary"
  defp role_badge_class("admin"), do: "badge-secondary"
  defp role_badge_class("coach"), do: "badge-primary"
  defp role_badge_class(_), do: "badge-ghost"

  defp list_users(actor, role_filter) do
    query = User

    query =
      if role_filter != "all", do: Ash.Query.filter(query, role_name == ^role_filter), else: query

    Ash.read!(query, actor: actor)
  end

  defp role_change_warning(current_role, new_role) do
    cond do
      current_role != "admin" && new_role == "admin" ->
        "Are you sure? This user will be granted full administrator privileges."

      current_role == "admin" && new_role != "admin" ->
        "Are you sure? Administrator privileges will be removed from this user."

      true ->
        nil
    end
  end

  defp list_coach_applications(actor) do
    CoachApplication
    |> Ash.Query.load(:user)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: actor)
  end

  defp update_coach_application_status(socket, id, status) do
    current_user = socket.assigns.current_user

    coach_application =
      Ash.get!(CoachApplication, id, actor: current_user, load: [:user])

    case coach_application
         |> Ash.Changeset.for_update(:set_status, %{status: status}, actor: current_user)
         |> Ash.update() do
      {:ok, updated_application} ->
        socket =
          if status == :approved do
            maybe_grant_coach_role(socket, updated_application.user)
          else
            socket
          end

        socket = maybe_send_coach_application_message(socket, updated_application, status)

        coach_applications = list_coach_applications(current_user)
        users = list_users(current_user, socket.assigns.role_filter)

        {:noreply,
         socket
         |> assign(:coach_applications, coach_applications)
         |> assign(:users, users)
         |> put_flash(:info, "Coach application #{status} successfully.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to update coach application.")}
    end
  end

  defp maybe_send_coach_application_message(socket, application, status) do
    message_body = coach_application_message(status)

    if message_body do
      case UserMessage
           |> Ash.Changeset.for_create(
             :send_system_message,
             %{body: message_body, recipient_id: application.user_id},
             actor: socket.assigns.current_user
           )
           |> Ash.create() do
        {:ok, _message} ->
          socket

        {:error, _error} ->
          put_flash(socket, :error, "Coach application updated, but message delivery failed.")
      end
    else
      socket
    end
  end

  defp coach_application_message(:approved),
    do: "TODO: add approved coach application message"

  defp coach_application_message(:denied),
    do: "TODO: add denied coach application message"

  defp coach_application_message(_status), do: nil

  defp maybe_grant_coach_role(socket, user) do
    if user.role_name == "student" do
      case user
           |> Ash.Changeset.for_update(:update_role, %{role: "coach"},
             actor: socket.assigns.current_user
           )
           |> Ash.update() do
        {:ok, _user} ->
          socket

        {:error, _error} ->
          put_flash(socket, :error, "Coach application approved, but role update failed.")
      end
    else
      socket
    end
  end

  defp coach_application_status_label(status) do
    status
    |> to_string()
    |> String.capitalize()
  end

  defp coach_application_pending?(:pending), do: true
  defp coach_application_pending?("pending"), do: true
  defp coach_application_pending?(_), do: false

  defp coach_application_badge_class(:pending), do: "badge-warning"
  defp coach_application_badge_class(:approved), do: "badge-success"
  defp coach_application_badge_class(:denied), do: "badge-error"
  defp coach_application_badge_class("pending"), do: "badge-warning"
  defp coach_application_badge_class("approved"), do: "badge-success"
  defp coach_application_badge_class("denied"), do: "badge-error"
  defp coach_application_badge_class(_), do: "badge-ghost"
end
