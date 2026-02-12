defmodule FosBjjWeb.Components.Authorization do
  @moduledoc """
  Components for role-based visibility control.

  These components conditionally render their children based on the current user's role
  and verification status. All components require the user to be verified.
  """
  use Phoenix.Component

  alias FosBjj.Accounts.User

  @doc """
  Renders content only if the current user is verified.

  Use this component for any feature that requires an authenticated user.
  Unverified users will not see the content.

  ## Examples

      <.verified_user_only current_user={@current_user}>
        <button>Add to Favorites</button>
      </.verified_user_only>

  """
  attr(:current_user, :map, default: nil, doc: "The current user")
  slot(:inner_block, required: true)

  def verified_user_only(assigns) do
    ~H"""
    <%= if User.verified?(@current_user) do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc """
  Renders content only if the current user is a verified admin.

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
  Renders content only if the current user is a verified coach, contributor, or admin.

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

  @doc """
  Renders content only if the current user is a verified contributor or admin.

  ## Examples

      <.contributor_or_admin_only current_user={@current_user}>
        <button>Add Video</button>
      </.contributor_or_admin_only>

  """
  attr(:current_user, :map, default: nil, doc: "The current user")
  slot(:inner_block, required: true)

  def contributor_or_admin_only(assigns) do
    ~H"""
    <%= if User.contributor_or_admin?(@current_user) do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end
end
