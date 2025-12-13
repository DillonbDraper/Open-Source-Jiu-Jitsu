defmodule FosBjjWeb.Components.Authorization do
  @moduledoc """
  Components for role-based visibility control.

  These components conditionally render their children based on the current user's role.
  """
  use Phoenix.Component

  alias FosBjj.Accounts.User

  @doc """
  Renders content only if the current user is an admin.

  ## Examples

      <.admin_only current_user={@current_user}>
        <button>Delete Everything</button>
      </.admin_only>

  """
  attr(:current_user, :map, default: nil, doc: "The current user")
  slot(:inner_block, required: true)

  def admin_only(assigns) do
    ~H"""
    <%= if User.admin?(@current_user) do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc """
  Renders content only if the current user is a coach or admin.

  ## Examples

      <.coach_or_admin_only current_user={@current_user}>
        <button>Edit Technique</button>
      </.coach_or_admin_only>

  """
  attr(:current_user, :map, default: nil, doc: "The current user")
  slot(:inner_block, required: true)

  def coach_or_admin_only(assigns) do
    ~H"""
    <%= if User.coach_or_admin?(@current_user) do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end
end
