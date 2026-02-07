defmodule FosBjjWeb.Live.Auth.SignInLive do
  @moduledoc """
  Custom sign-in LiveView that includes username field in registration.
  """

  use FosBjjWeb, :live_view

  alias AshAuthentication.Phoenix.Components

  @impl true
  def mount(_params, session, socket) do
    overrides =
      session
      |> Map.get("overrides", [AshAuthentication.Phoenix.Overrides.Default])

    socket =
      socket
      |> assign(overrides: overrides)
      |> assign_new(:otp_app, fn -> :fos_bjj end)
      |> assign(:path, session["path"] || "/")
      |> assign(:reset_path, session["reset_path"])
      |> assign(:register_path, session["register_path"])
      |> assign(:current_tenant, session["tenant"])
      |> assign(:context, session["context"] || %{})
      |> assign(:auth_routes_prefix, session["auth_routes_prefix"])
      |> assign(:gettext_fn, session["gettext_fn"])

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid h-screen place-items-center bg-base-100">
      <.live_component
        module={Components.Banner}
        id="sign-in-banner"
        overrides={@overrides}
        gettext_fn={@gettext_fn}
      />

      <.live_component
        module={Components.Password}
        id="password-sign-in"
        strategy={password_strategy()}
        path={@path}
        reset_path={@reset_path}
        register_path={@register_path}
        live_action={@live_action}
        overrides={@overrides}
        current_tenant={@current_tenant}
        context={@context}
        auth_routes_prefix={@auth_routes_prefix}
        gettext_fn={@gettext_fn}
      >
        <:register_extra :let={form}>
          <div class="mt-2 mb-2 dark:text-white">
            <.input field={form[:user_name]} type="text" label="Username" required />
          </div>
        </:register_extra>
      </.live_component>
    </div>
    """
  end

  defp password_strategy do
    AshAuthentication.Info.strategy!(FosBjj.Accounts.User, :password)
  end
end
