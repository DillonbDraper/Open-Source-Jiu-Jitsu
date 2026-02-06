defmodule FosBjjWeb.Components.UserProfilePanel do
  @moduledoc """
  Component for displaying user profile header information.
  The profile modal and academy drawer are rendered at the LiveView level
  to prevent unmounting issues when drawer state changes.
  """
  use FosBjjWeb, :html

  alias FosBjj.Accounts.User

  attr :current_user, :map, required: true
  attr :coach_application_status, :any, required: true

  def user_profile_panel(assigns) do
    ~H"""
    <header class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <.h1 class="text-3xl font-extrabold tracking-tight text-base-content">
            Welcome, {@current_user.user_name}
          </.h1>
          <p class="mt-2 text-lg text-base-content/70">
            Personal/Training details to guide your experience
          </p>
        </div>

        <div class="flex flex-col items-start gap-3">
          <%= if @current_user.role_name == "student" &&
                @coach_application_status != :denied &&
                User.coach_application_eligible?(@current_user) do %>
            <%= if @coach_application_status == :pending do %>
              <div class="flex items-center gap-2">
                <.tooltip
                  id="coach-application-processing-tooltip"
                  inline={true}
                  position="bottom"
                  width="triple_large"
                  trigger_class="inline-flex"
                  content_class="max-w-xs whitespace-normal text-sm"
                >
                  <:trigger>
                    <span class="inline-flex cursor-help">
                      <.icon
                        name="hero-information-circle"
                        class="size-5 text-base-content/70"
                      />
                    </span>
                  </:trigger>
                  <:content>
                    Your application to become a coach and gain the ability to upload videos, share with your students, and more is
                    being processed. Thank you for your interest in contributing to OSSBJJ!
                  </:content>
                </.tooltip>
                <.button
                  id="coach-application-processing"
                  class="btn btn-primary"
                  disabled
                >
                  Application processing...
                </.button>
              </div>
            <% else %>
              <.button
                id="open-coach-application"
                phx-click="open_coach_application_modal"
                class="btn btn-primary"
              >
                Become A Coach
              </.button>
            <% end %>
          <% end %>

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
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Username
          </p>
          <p class="mt-2 text-lg font-semibold text-base-content">
            {@current_user.user_name}
          </p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-50 px-4 py-3">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Belt Rank
          </p>
          <p class="mt-2 text-lg font-semibold text-base-content">
            {belt_label(@current_user.bjj_belt)}
          </p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-50 px-4 py-3">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            High Level Experience
          </p>
          <p class="mt-2 text-lg font-semibold text-base-content">
            {if @current_user.other_high_level_experience, do: "Yes", else: "No"}
          </p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-50 px-4 py-3">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Academies
          </p>
          <div class="mt-2 flex flex-wrap gap-2">
            <%= if @current_user.academies == [] do %>
              <span class="text-sm text-base-content/70">Not set</span>
            <% else %>
              <%= for academy <- @current_user.academies do %>
                <span class="badge badge-sm">{academy.name}</span>
              <% end %>
            <% end %>
          </div>
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
