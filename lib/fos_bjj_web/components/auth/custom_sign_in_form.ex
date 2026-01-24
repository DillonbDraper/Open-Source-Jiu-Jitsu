defmodule FosBjjWeb.Components.Auth.CustomSignInForm do
  @moduledoc """
  Custom sign-in form that shows "Email or Username" as the identity field label.
  """

  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot."

  use AshAuthentication.Phoenix.Web, :live_component

  alias AshAuthentication.{Info, Phoenix.Components.Password, Strategy}
  alias AshPhoenix.Form

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 5, auth_path: 6, debug_form_errors: 1]

  import Slug

  @impl true
  def update(assigns, socket) do
    strategy = assigns.strategy
    domain = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(assigns)
      |> assign(trigger_action: false, subject_name: subject_name)
      |> assign_new(:label, fn -> Phoenix.Naming.humanize(strategy.sign_in_action_name) end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    context =
      Ash.Helpers.deep_merge_maps(assigns[:context] || %{}, %{
        strategy: strategy,
        private: %{ash_authentication?: true}
      })

    context =
      if Map.get(socket.assigns.strategy, :sign_in_tokens_enabled?) do
        Map.put(context, :token_type, :sign_in)
      else
        context
      end

    form =
      strategy.resource
      |> Form.for_action(strategy.sign_in_action_name,
        domain: domain,
        as: subject_name |> to_string() |> slugify(),
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.sign_in_action_name}"
          |> slugify(),
        tenant: assigns[:current_tenant],
        context: context
      )

    socket = assign(socket, form: form, trigger_action: false, subject_name: subject_name)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@overrides, :label_class)}>{@label}</h2>
      <% end %>

      <.form
        :let={form}
        for={@form}
        id={@form.id}
        phx-change="change"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={auth_path(@socket, @subject_name, @auth_routes_prefix, @strategy, :sign_in)}
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <%!-- Custom identity field with "Email or Username" label --%>
        <div class="mt-2 mb-2 dark:text-white">
          <label for={form[@strategy.identity_field].id} class="block text-sm font-medium text-gray-700 mb-1 dark:text-white">
            Email or Username
          </label>
          <input
            type="text"
            id={form[@strategy.identity_field].id}
            name={form[@strategy.identity_field].name}
            value={Phoenix.HTML.Form.normalize_value("text", form[@strategy.identity_field].value)}
            class="appearance-none block w-full px-3 py-2 border rounded-md shadow-sm placeholder-gray-400 focus:outline-none sm:text-sm dark:text-white border-gray-300 focus:ring-blue-400 focus:border-blue-500"
            autofocus="true"
          />
          <%= if form[@strategy.identity_field].errors != [] do %>
            <ul class="text-red-400 font-light my-3 italic text-sm">
              <%= for {msg, _opts} <- form[@strategy.identity_field].errors do %>
                <li>{msg}</li>
              <% end %>
            </ul>
          <% end %>
        </div>

        <Password.Input.password_field
          strategy={@strategy}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <%= if @inner_block do %>
          <div class={override_for(@overrides, :slot_class)}>
            {render_slot(@inner_block, form)}
          </div>
        <% end %>

        <Password.Input.submit
          strategy={@strategy}
          id={@form.id <> "-submit"}
          form={form}
          action={:sign_in}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("change", params, socket) do
    params = get_params(params, socket.assigns.strategy)

    form =
      socket.assigns.form
      |> Form.validate(params, errors: false)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", params, socket) do
    params = get_params(params, socket.assigns.strategy)

    if Map.get(socket.assigns.strategy, :sign_in_tokens_enabled?) do
      case Form.submit(socket.assigns.form,
             params: params,
             read_one?: true
           ) do
        {:ok, user} ->
          auth_path_params = %{token: user.__metadata__.token}

          validate_sign_in_token_path =
            auth_path(
              socket,
              socket.assigns.subject_name,
              socket.assigns.auth_routes_prefix,
              socket.assigns.strategy,
              :sign_in_with_token,
              auth_path_params
            )

          {:noreply, redirect(socket, to: validate_sign_in_token_path)}

        {:error, form} ->
          debug_form_errors(form)

          {:noreply,
           assign(socket, :form, Form.clear_value(form, socket.assigns.strategy.password_field))}
      end
    else
      form = Form.validate(socket.assigns.form, params)

      socket =
        socket
        |> assign(:form, form)
        |> assign(:trigger_action, form.valid?)

      {:noreply, socket}
    end
  end

  defp get_params(params, strategy) do
    param_key =
      strategy.resource
      |> Info.authentication_subject_name!()
      |> to_string()
      |> slugify()

    Map.get(params, param_key, %{})
  end
end
