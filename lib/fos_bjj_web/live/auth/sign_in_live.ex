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
            <label
              for={form[:user_name].id}
              class="block text-sm font-medium text-gray-700 mb-1 dark:text-white"
            >
              Username
            </label>
            <input
              type="text"
              id={form[:user_name].id}
              name={form[:user_name].name}
              value={Phoenix.HTML.Form.normalize_value("text", form[:user_name].value)}
              class="appearance-none block w-full px-3 py-2 border rounded-md shadow-sm placeholder-gray-400 focus:outline-none sm:text-sm dark:text-white border-gray-300 focus:ring-blue-400 focus:border-blue-500"
              required
            />
            <%= if form[:user_name].errors != [] do %>
              <ul class="text-red-400 font-light my-3 italic text-sm">
                <%= for {msg, _opts} <- form[:user_name].errors do %>
                  <li>{msg}</li>
                <% end %>
              </ul>
            <% end %>
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
