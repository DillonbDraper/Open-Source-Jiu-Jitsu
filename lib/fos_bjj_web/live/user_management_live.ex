defmodule FosBjjWeb.UserManagementLive do
  use FosBjjWeb, :live_view
  alias FosBjj.Accounts.User
  require Ash.Query

  on_mount {FosBjjWeb.LiveUserAuth, :live_admin_required}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    users = Ash.read!(User, actor: current_user)

    {:ok,
     socket
     |> assign(:page_title, "User Management")
     |> assign(:users, users)
     |> assign(:role_filter, "all")
     |> assign(:editing_user, nil)
     |> assign(:target_role, nil)}
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
end
