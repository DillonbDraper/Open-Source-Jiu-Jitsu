defmodule FosBjjWeb.Components.UserProfilePanel do
  @moduledoc """
  Component for displaying user profile header information.
  """
  use FosBjjWeb, :html

  attr :current_user, :map, required: true
  attr :academy_memberships, :list, required: true

  def user_profile_panel(assigns) do
    ~H"""
    <header class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <.h1 class="text-3xl font-extrabold tracking-tight text-base-content">
            Welcome, {@current_user.user_name}
          </.h1>
          <.p size="text-lg" class="mt-2 text-base-content/70">
            Personal Info
          </.p>
        </div>

        <div class="flex flex-col items-start gap-3">
          <.button
            id="edit-profile"
            phx-click="open_profile_modal"
            class="btn btn-ghost"
          >
            Edit Profile
          </.button>
        </div>
      </div>

      <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="rounded-2xl border border-base-200 bg-base-50 px-4 py-3">
          <.p
            size="text-xs"
            font_weight="font-semibold"
            class="uppercase tracking-wide text-base-content/60"
          >
            Username
          </.p>
          <.p size="text-lg" font_weight="font-semibold" class="mt-2 text-base-content">
            {@current_user.user_name}
          </.p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-50 px-4 py-3">
          <.p
            size="text-xs"
            font_weight="font-semibold"
            class="uppercase tracking-wide text-base-content/60"
          >
            Belt Rank
          </.p>
          <.p size="text-lg" font_weight="font-semibold" class="mt-2 text-base-content">
            {belt_label(@current_user.bjj_belt)}
          </.p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-50 px-4 py-3">
          <.p
            size="text-xs"
            font_weight="font-semibold"
            class="uppercase tracking-wide text-base-content/60"
          >
            Other High Level Experience
          </.p>
          <.p size="text-lg" font_weight="font-semibold" class="mt-2 text-base-content">
            {if @current_user.other_high_level_experience, do: "Yes", else: "No"}
          </.p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-50 px-4 py-3">
          <.p
            size="text-xs"
            font_weight="font-semibold"
            class="uppercase tracking-wide text-base-content/60"
          >
            Academies
          </.p>
          <%= if @academy_memberships == [] do %>
            <span class="mt-2 inline-flex text-sm text-base-content/70">Not set</span>
          <% else %>
            <div class="mt-3 space-y-2">
              <%= for membership <- @academy_memberships do %>
                <% academy = membership.academy %>
                <div class="flex items-center justify-between gap-3 text-sm">
                  <span class="font-medium text-base-content">
                    {academy.name}
                  </span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </header>
    """
  end

  defp belt_label(nil), do: "Not set"

  defp belt_label(belt) when is_atom(belt) do
    "#{belt |> Atom.to_string() |> String.capitalize()} belt"
  end

  defp belt_label(belt) when is_binary(belt) do
    "#{String.capitalize(belt)} belt"
  end

  @doc "Returns the belt options for select fields"
  def belt_options do
    [
      {"White", :white},
      {"Blue", :blue},
      {"Purple", :purple},
      {"Brown", :brown},
      {"Black", :black}
    ]
  end
end
