defmodule FosBjjWeb.Components.FollowersTableComponent do
  @moduledoc """
  LiveComponent for displaying users who follow a coach (informational only).
  """
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.StudentCoachRelationship
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :followers, nil)}
  end

  @impl true
  def update(%{current_user: user} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns.followers == nil do
        followers = list_followers(user)
        assign(socket, :followers, followers)
      else
        socket
      end

    {:ok, socket}
  end

  defp list_followers(user) do
    StudentCoachRelationship
    |> Ash.Query.filter(coach_id == ^user.id)
    |> Ash.Query.load(:learner)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: user)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
      <div class="flex justify-between items-center mb-4">
        <.h3 class="text-lg font-medium">My Followers</.h3>
        <span class="badge badge-primary badge-outline">{length(@followers)} student(s)</span>
      </div>

      <%= if @followers == [] do %>
        <div class="rounded-xl border border-dashed border-base-200 bg-base-50 px-4 py-10 text-center">
          <.p class="text-sm text-base-content/70">No students are following you yet.</.p>
        </div>
      <% else %>
        <.table padding="extra_small" border="medium" rows={@followers}>
          <:col :let={relationship} label="Username">
            {relationship.learner.user_name}
          </:col>
          <:col :let={relationship} label="Email">
            <span class="text-base-content/70">{relationship.learner.email}</span>
          </:col>
          <:col :let={relationship} label="Following Since">
            {Calendar.strftime(relationship.inserted_at, "%b %d, %Y")}
          </:col>
        </.table>
      <% end %>
    </div>
    """
  end
end
