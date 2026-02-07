defmodule FosBjjWeb.AcademyLive.NewAcademyForm do
  use FosBjjWeb, :live_component
  import FosBjjWeb.Components.Drawer

  alias FosBjj.Accounts.Academy

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if Map.has_key?(socket.assigns, :form) do
      {:ok, socket}
    else
      form =
        AshPhoenix.Form.for_create(Academy, :create,
          as: "academy",
          actor: socket.assigns.current_user
        )
        |> to_form()

      {:ok, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("validate", %{"academy" => params}, socket) do
    form =
      AshPhoenix.Form.validate(socket.assigns.form, params, actor: socket.assigns.current_user)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"academy" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, academy} ->
        send(self(), {__MODULE__, {:academy_created, academy}})
        hide_drawer("academy-drawer", "right")
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.h2 size="text-2xl" font_weight="font-bold">Add a New Academy</.h2>
        <.p size="text-sm" class="mt-2 text-base-content/70">
          Can't find your gym? Create it here and we'll add it to your profile.
        </.p>
      </div>

      <.form
        for={@form}
        id="academy-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <div class="space-y-6">
          <.input
            field={@form[:name]}
            label="Academy Name"
            placeholder="Enter academy name"
          />

          <div class="flex gap-4">
            <.button type="submit" class="btn btn-primary">
              Create Academy
            </.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
