defmodule FosBjjWeb.Components.CoachesTableComponent do
  @moduledoc """
  LiveComponent for displaying coaches a user follows and adding new coach relationships.
  """
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.StudentCoachRelationship
  alias FosBjj.Accounts.UserMessage
  alias FosBjj.Accounts.User
  import FosBjjWeb.Components.SearchField
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:coaches, nil)
     |> assign(:show_follow_modal, false)
     |> assign(:coach_search_query, "")
     |> assign(:search_results, [])
     |> assign(:selected_coach, nil)
     |> assign(:show_confirm, false)}
  end

  @impl true
  def update(%{current_user: user} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns.coaches == nil do
        coaches = list_followed_coaches(user)
        assign(socket, :coaches, coaches)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("open_follow_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_follow_modal, true)
     |> assign(:coach_search_query, "")
     |> assign(:search_results, [])
     |> assign(:selected_coach, nil)
     |> assign(:show_confirm, false)}
  end

  @impl true
  def handle_event("close_follow_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_follow_modal, false)
     |> assign(:coach_search_query, "")
     |> assign(:search_results, [])
     |> assign(:selected_coach, nil)
     |> assign(:show_confirm, false)}
  end

  @impl true
  def handle_event("search_coaches", %{"query" => query}, socket) do
    user = socket.assigns.current_user

    results =
      if String.length(query) >= 2 do
        search_unfollowed_coaches(user, query)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:coach_search_query, query)
     |> assign(:search_results, results)
     |> assign(:selected_coach, nil)
     |> assign(:show_confirm, false)}
  end

  @impl true
  def handle_event("select_coach", %{"id" => id}, socket) do
    coach_id = String.to_integer(id)
    coach = Enum.find(socket.assigns.search_results, &(&1.id == coach_id))

    {:noreply,
     socket
     |> assign(:selected_coach, coach)
     |> assign(:show_confirm, true)}
  end

  @impl true
  def handle_event("cancel_confirm", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_coach, nil)
     |> assign(:show_confirm, false)}
  end

  @impl true
  def handle_event("confirm_follow", _, socket) do
    user = socket.assigns.current_user
    coach = socket.assigns.selected_coach

    case StudentCoachRelationship
         |> Ash.Changeset.for_create(:follow, %{coach_id: coach.id}, actor: user)
         |> Ash.create() do
      {:ok, _relationship} ->
        send_follow_notification(user, coach)
        coaches = list_followed_coaches(user)

        {:noreply,
         socket
         |> assign(:coaches, coaches)
         |> assign(:show_follow_modal, false)
         |> assign(:selected_coach, nil)
         |> assign(:show_confirm, false)
         |> put_flash(:info, "You are now following #{coach.user_name}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to follow coach")}
    end
  end

  @impl true
  def handle_event("unfollow_coach", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    relationship_id = String.to_integer(id)

    StudentCoachRelationship
    |> Ash.get!(relationship_id, actor: user)
    |> Ash.destroy!(actor: user)

    coaches = list_followed_coaches(user)

    {:noreply,
     socket
     |> assign(:coaches, coaches)
     |> put_flash(:info, "Unfollowed coach")}
  end

  defp list_followed_coaches(user) do
    StudentCoachRelationship
    |> Ash.Query.filter(learner_id == ^user.id)
    |> Ash.Query.load(:coach)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: user)
  end

  defp search_unfollowed_coaches(user, query) do
    followed_ids =
      StudentCoachRelationship
      |> Ash.Query.filter(learner_id == ^user.id)
      |> Ash.Query.select([:coach_id])
      |> Ash.read!(actor: user)
      |> Enum.map(& &1.coach_id)

    query_string = "%#{query}%"

    User
    |> Ash.Query.filter(role_name in ["coach", "admin"])
    |> Ash.Query.filter(id != ^user.id)
    |> Ash.Query.filter(id not in ^followed_ids)
    |> Ash.Query.filter(ilike(user_name, ^query_string))
    |> Ash.Query.limit(10)
    |> Ash.read!(actor: user)
  end

  defp send_follow_notification(learner, coach) do
    message_body = "#{learner.user_name} is now following you as a student!"

    UserMessage
    |> Ash.Changeset.for_create(:send_system_message, %{
      body: message_body,
      recipient_id: coach.id
    })
    |> Ash.create!()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm border border-base-200 p-6">
      <div class="flex justify-between items-center mb-4">
        <.h3 class="text-lg font-medium">Coaches I Follow</.h3>
        <.button
          phx-click="open_follow_modal"
          phx-target={@myself}
          class="btn btn-primary btn-sm"
        >
          <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Follow a Coach
        </.button>
      </div>

      <%= if @coaches == [] do %>
        <div class="rounded-xl border border-dashed border-base-200 bg-base-50 px-4 py-10 text-center">
          <.p class="text-sm text-base-content/70">You are not following any coaches yet.</.p>
        </div>
      <% else %>
        <.table padding="extra_small" border="medium" rows={@coaches}>
          <:col :let={relationship} label="Username">
            {relationship.coach.user_name}
          </:col>
          <:col :let={relationship} label="Role">
            <span class="badge badge-sm">
              {String.capitalize(relationship.coach.role_name)}
            </span>
          </:col>
          <:col :let={relationship} label="Since">
            {Calendar.strftime(relationship.inserted_at, "%b %d, %Y")}
          </:col>
          <:action :let={relationship}>
            <button
              type="button"
              phx-click="unfollow_coach"
              phx-value-id={relationship.id}
              phx-target={@myself}
              data-confirm="Are you sure you want to unfollow this coach?"
              class="p-1 text-error cursor-pointer hover:bg-error/10 rounded-full transition-colors"
            >
              <.icon name="hero-user-minus" class="w-5 h-5" />
            </button>
          </:action>
        </.table>
      <% end %>

      <.modal
        :if={@show_follow_modal}
        show
        id="follow-coach-modal"
        size="large"
        on_cancel={JS.push("close_follow_modal", target: @myself)}
      >
        <div class="space-y-4">
          <.h3 class="text-xl font-semibold">Follow a Coach</.h3>

          <%= if @show_confirm && @selected_coach do %>
            <div class="alert alert-warning">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
              <div>
                <p class="font-medium">
                  Are you sure you wish to follow coach {@selected_coach.user_name}?
                </p>
                <p class="text-sm opacity-80 mt-1">
                  OSSBJJ takes no responsibility for any messages broadcast alongside videos to watch.
                </p>
              </div>
            </div>
            <div class="flex justify-end gap-2 mt-4">
              <.button
                phx-click="cancel_confirm"
                phx-target={@myself}
                class="btn btn-ghost"
              >
                Cancel
              </.button>
              <.button
                phx-click="confirm_follow"
                phx-target={@myself}
                class="btn btn-primary"
              >
                Confirm Follow
              </.button>
            </div>
          <% else %>
            <form phx-change="search_coaches" phx-target={@myself}>
              <.search_field
                name="query"
                value={@coach_search_query}
                placeholder="Search coaches by username (min 2 characters)..."
                phx-debounce="300"
              />
            </form>

            <%= if @search_results != [] do %>
              <div class="space-y-2 max-h-60 overflow-y-auto">
                <%= for coach <- @search_results do %>
                  <button
                    type="button"
                    phx-click="select_coach"
                    phx-value-id={coach.id}
                    phx-target={@myself}
                    class="w-full p-3 text-left rounded-lg border border-base-200 hover:bg-base-200 transition-colors flex items-center justify-between"
                  >
                    <span>{coach.user_name}</span>
                    <span class="badge badge-sm">{String.capitalize(coach.role_name)}</span>
                  </button>
                <% end %>
              </div>
            <% else %>
              <%= if String.length(@coach_search_query) >= 2 do %>
                <p class="text-sm text-base-content/70 text-center py-4">
                  No coaches found matching "{@coach_search_query}"
                </p>
              <% else %>
                <p class="text-sm text-base-content/70 text-center py-4">
                  Start typing to search for coaches (min 2 characters)
                </p>
              <% end %>
            <% end %>
          <% end %>
        </div>
      </.modal>
    </div>
    """
  end
end
