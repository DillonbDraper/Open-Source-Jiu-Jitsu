defmodule FosBjjWeb.UserManagementLive do
  use FosBjjWeb, :live_view
  alias FosBjj.Accounts.User
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user.role == :admin do
      users = Ash.read!(User, actor: socket.assigns.current_user)

      {:ok,
       socket
       |> assign(:page_title, "User Management")
       |> assign(:users, users)
       |> assign(:role_filter, "all")}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("filter_role", %{"role" => role}, socket) do
    query = User
    query = if role != "all", do: Ash.Query.filter(query, role == ^role), else: query
    users = Ash.read!(query, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:role_filter, role)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold">{@page_title}</h1>
        <p class="text-gray-600">View and manage system users.</p>
      </div>

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
            <span class={"badge " <> role_badge_class(user.role)}>
              {user.role}
            </span>
          </:col>
        </.table>
      </div>
    </div>
    """
  end

  defp role_badge_class(:admin), do: "badge-secondary"
  defp role_badge_class(:coach), do: "badge-primary"
  defp role_badge_class(_), do: "badge-ghost"
end
