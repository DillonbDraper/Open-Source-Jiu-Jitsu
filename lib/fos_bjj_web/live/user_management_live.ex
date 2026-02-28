defmodule FosBjjWeb.UserManagementLive do
  use FosBjjWeb, :live_view
  alias FosBjj.Accounts.ContributorApplication
  alias FosBjj.Accounts.User
  alias FosBjj.Accounts.UserMessage
  require Ash.Query

  on_mount {FosBjjWeb.LiveUserAuth, :live_admin_required}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    users = Ash.read!(User, actor: current_user)
    contributor_applications = list_contributor_applications(current_user, "pending")

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:role_filter, "all")
     |> assign(:editing_user, nil)
     |> assign(:target_role, nil)
     |> assign(:application_status_filter, "pending")
     |> assign(:contributor_applications, contributor_applications)}
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
         |> put_flash(:success, "User role updated successfully.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :danger, "Failed to update role.")}
    end
  end

  @impl true
  def handle_event("approve_contributor_application", %{"id" => id}, socket) do
    update_contributor_application_status(socket, id, :approved)
  end

  @impl true
  def handle_event("deny_contributor_application", %{"id" => id}, socket) do
    update_contributor_application_status(socket, id, :denied)
  end

  @impl true
  def handle_event("filter_application_status", %{"status" => status}, socket) do
    contributor_applications = list_contributor_applications(socket.assigns.current_user, status)

    {:noreply,
     socket
     |> assign(:application_status_filter, status)
     |> assign(:contributor_applications, contributor_applications)}
  end

  defp role_badge_class(:admin), do: "badge-secondary"
  defp role_badge_class(:coach), do: "badge-primary"
  defp role_badge_class(:contributor), do: "badge-accent"
  defp role_badge_class("admin"), do: "badge-secondary"
  defp role_badge_class("coach"), do: "badge-primary"
  defp role_badge_class("contributor"), do: "badge-accent"
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

  defp list_contributor_applications(actor, status_filter) do
    query =
      ContributorApplication
      |> Ash.Query.load(:user)
      |> Ash.Query.sort(inserted_at: :desc)

    query =
      if status_filter != "all" do
        Ash.Query.filter(query, status == ^status_filter)
      else
        query
      end

    Ash.read!(query, actor: actor)
  end

  defp update_contributor_application_status(socket, id, status) do
    current_user = socket.assigns.current_user

    contributor_application =
      Ash.get!(ContributorApplication, id, actor: current_user, load: [:user])

    case contributor_application
         |> Ash.Changeset.for_update(:set_status, %{status: status}, actor: current_user)
         |> Ash.update() do
      {:ok, updated_application} ->
        socket =
          if status == :approved do
            grant_contributor_role(socket, updated_application.user)
          else
            socket
          end

        socket = send_contributor_application_message(socket, updated_application, status)

        contributor_applications =
          list_contributor_applications(current_user, socket.assigns.application_status_filter)

        users = list_users(current_user, socket.assigns.role_filter)

        {:noreply,
         socket
         |> assign(:contributor_applications, contributor_applications)
         |> assign(:users, users)
         |> put_flash(:success, "Contributor application #{status} successfully.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :danger, "Failed to update contributor application.")}
    end
  end

  defp send_contributor_application_message(socket, application, status) do
    message_body = contributor_application_message(status)

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
        put_flash(
          socket,
          :danger,
          "Contributor application updated, but message delivery failed."
        )
    end
  end

  defp contributor_application_message(:approved),
    do:
      "Parabens! You have been approved to become a contributor on OSSBJJ! Please help contribute to the community by helping to make this resource the best that it can be."

  defp contributor_application_message(:denied),
    do:
      "Unfortunately, your application to OSSBJJ has been denied. We thank you for your interest in contributing, but at this time we either have enough contributors or your qualifications were found to be insufficient. Please do not take this decision personally, as it was not made lightly. Thank you for using OSSBJJ."

  defp grant_contributor_role(socket, user) do
    case user
         |> Ash.Changeset.for_update(:update_role, %{role: "contributor"},
           actor: socket.assigns.current_user
         )
         |> Ash.update() do
      {:ok, _user} ->
        socket

      {:error, _error} ->
        put_flash(socket, :danger, "Contributor application approved, but role update failed.")
    end
  end

  # I don't love this but it is necessary here
  defp contributor_application_status_label(status) do
    status
    |> to_string()
    |> String.capitalize()
  end

  defp contributor_application_pending?("pending"), do: true
  defp contributor_application_pending?(_), do: false

  defp contributor_application_badge_class("pending"), do: "badge-warning"
  defp contributor_application_badge_class("approved"), do: "badge-success"
  defp contributor_application_badge_class("denied"), do: "badge-error"
  defp contributor_application_badge_class(_), do: "badge-ghost"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_width current_user={assigns[:current_user]} socket={@socket}>
      <div class="space-y-6">
        <header>
          <.h1 class="text-3xl font-extrabold tracking-tight text-base-content">
            User Management
          </.h1>
        </header>

        <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
          <.h3 class="text-lg font-medium">Users</.h3>
          <.p class="text-sm text-base-content/70">
            View and manage system users.
          </.p>
          <div class="flex justify-end mb-4">
            <form phx-change="filter_role" class="flex items-center gap-2">
              <label class="text-sm font-medium">Filter by Role:</label>
              <.native_select name="role" size="small" class="min-w-[8rem]">
                <:option value="all" selected={@role_filter == "all"}>All Roles</:option>
                <:option value="user" selected={@role_filter == "user"}>User</:option>
                <:option value="contributor" selected={@role_filter == "contributor"}>
                  Contributor
                </:option>
                <:option value="coach" selected={@role_filter == "coach"}>Coach</:option>
                <:option value="admin" selected={@role_filter == "admin"}>Admin</:option>
              </.native_select>
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
                  <.native_select name="role" size="extra_small" class="min-w-[7rem]">
                    <:option value="student" selected={@target_role == "student"}>
                      Student
                    </:option>
                    <:option value="contributor" selected={@target_role == "contributor"}>
                      Contributor
                    </:option>
                    <:option value="coach" selected={@target_role == "coach"}>Coach</:option>
                    <:option value="admin" selected={@target_role == "admin"}>Admin</:option>
                  </.native_select>
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
                  <%= if assigns[:current_user].id != user.id do %>
                    <.button
                      class="btn btn-ghost btn-xs"
                      phx-click="edit_role"
                      phx-value-id={user.id}
                      aria-label="Edit Role"
                      title="Edit Video"
                    >
                      <.icon name="hero-pencil-solid" class="w-4 h-4" />
                    </.button>
                  <% end %>
                </div>
              <% end %>
            </:col>
          </.table>
        </div>

        <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
          <div class="flex items-center justify-between mb-4">
            <div>
              <.h3 class="text-lg font-medium">Contributor Applications</.h3>
              <.p class="text-sm text-base-content/70">
                Review and approve applications for contributor access.
              </.p>
            </div>
          </div>

          <div class="flex justify-end mb-4">
            <form phx-change="filter_application_status" class="flex items-center gap-2">
              <label class="text-sm font-medium">Filter by Status:</label>
              <.native_select name="status" size="small" class="min-w-[8rem]">
                <:option value="pending" selected={@application_status_filter == "pending"}>
                  Pending
                </:option>
                <:option value="approved" selected={@application_status_filter == "approved"}>
                  Approved
                </:option>
                <:option value="denied" selected={@application_status_filter == "denied"}>
                  Denied
                </:option>
                <:option value="all" selected={@application_status_filter == "all"}>All</:option>
              </.native_select>
            </form>
          </div>

          <.table rows={@contributor_applications}>
            <:col :let={application} label="Applicant">
              <div class="space-y-1">
                <div class="font-medium">{application.user.email}</div>
                <div class="text-xs text-base-content/60">User ID: {application.user_id}</div>
              </div>
            </:col>
            <:col :let={application} label="Message">
              <.popover
                id={"contributor-app-body-#{application.id}"}
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
              <span class={"badge " <> contributor_application_badge_class(application.status)}>
                {contributor_application_status_label(application.status)}
              </span>
            </:col>
            <:col :let={application} label="Submitted">
              {Calendar.strftime(application.inserted_at, "%b %d, %Y %H:%M %p")}
            </:col>
            <:action :let={application}>
              <div class="flex gap-2">
                <.button
                  class="btn btn-success btn-xs"
                  phx-click="approve_contributor_application"
                  phx-value-id={application.id}
                  disabled={!contributor_application_pending?(application.status)}
                >
                  Approve
                </.button>
                <.button
                  class="btn btn-error btn-xs"
                  phx-click="deny_contributor_application"
                  phx-value-id={application.id}
                  disabled={!contributor_application_pending?(application.status)}
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
end
