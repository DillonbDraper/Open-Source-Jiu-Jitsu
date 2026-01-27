defmodule FosBjjWeb.CoachApplicationForm do
  use FosBjjWeb, :live_component

  alias FosBjj.Accounts.CoachApplication
  alias FosBjj.Accounts.CoachApplicationEmail

  @impl true
  def mount(socket) do
    {:ok,
     allow_upload(socket, :coach_proof,
       accept: ~w(.jpg .jpeg .png .gif .webp .pdf),
       max_entries: 1,
       max_file_size: 8_000_000
     )}
  end

  @impl true
  def update(assigns, socket) do
    previous_show = socket.assigns[:show] || false
    socket = assign(socket, assigns)

    socket =
      cond do
        socket.assigns.show && !previous_show ->
          assign(socket, :form, build_form(socket.assigns.current_user))

        is_nil(socket.assigns[:form]) ->
          assign(socket, :form, build_form(socket.assigns.current_user))

        true ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"coach_application" => params}, socket) do
    form =
      AshPhoenix.Form.validate(socket.assigns.form, params, actor: socket.assigns.current_user)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("submit", %{"coach_application" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, application} ->
        attachments =
          consume_uploaded_entries(socket, :coach_proof, fn %{path: path}, entry ->
            data = File.read!(path)

            {:ok,
             Swoosh.Attachment.new({:data, data},
               filename: entry.client_name,
               content_type: entry.client_type
             )}
          end)

        result =
          CoachApplicationEmail.deliver_application(
            socket.assigns.current_user,
            application.body,
            attachments
          )

        send(self(), {:coach_application_submitted, result})

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("close", _, socket) do
    send(self(), {:coach_application_closed})
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :coach_proof, ref)}
  end

  defp build_form(user) do
    CoachApplication
    |> AshPhoenix.Form.for_create(:submit, as: "coach_application", actor: user)
    |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%= if @show do %>
        <.modal
          show
          id={"#{@id}-modal"}
          size="large"
          on_cancel={JS.push("close", target: @myself)}
        >
          <div class="space-y-6">
            <div>
              <.h3 class="text-2xl font-semibold text-base-content">
                Apply to Become a Coach
              </.h3>
              <p class="mt-2 text-sm text-base-content/70">
                We review every application manually. Please share your background and include
                proof if you can.
              </p>
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <div class="rounded-2xl border border-base-200 bg-base-100 p-4 shadow-sm">
                <.h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                  Eligibility
                </.h4>
                <.list class="mt-3 space-y-2 text-sm text-base-content/80">
                  <:item icon="hero-check-circle">
                    BJJ black belt, or proven high level in another art
                  </:item>
                  <:item icon="hero-check-circle">Evidence of rank or achievements</:item>
                </.list>
              </div>

              <div class="rounded-2xl border border-base-200 bg-base-100 p-4 shadow-sm">
                <.h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                  Responsibilities
                </.h4>
                <.list class="mt-3 space-y-2 text-sm text-base-content/80">
                  <:item icon="hero-shield-check">No self-promotion in uploads</:item>
                  <:item icon="hero-shield-check">
                    Broadcast messages are for students, never spam
                  </:item>
                </.list>
              </div>
            </div>

            <.form
              for={@form}
              id={"#{@id}-form"}
              phx-change="validate"
              phx-submit="submit"
              phx-target={@myself}
              class="space-y-4"
              multipart
            >
              <.input
                field={@form[:body]}
                type="textarea"
                label="Tell us about your experience"
                placeholder="Share your belt, teaching background, competition history, or other qualifications."
                rows="6"
                required
              />

              <div>
                <.file_field
                  id={"#{@id}-proof"}
                  target={:coach_proof}
                  uploads={@uploads}
                  dropzone
                  dropzone_type="file"
                  dropzone_title="Upload proof (optional)"
                  dropzone_description="Images or PDFs up to 8MB."
                  class="bg-base-100"
                  phx_target={@myself}
                />
              </div>

              <div class="flex flex-wrap items-center justify-between gap-3">
                <p class="text-xs text-base-content/60">
                  By applying, you agree to use coach tools responsibly and avoid self-promotion.
                </p>
                <div class="flex gap-2">
                  <.button
                    type="button"
                    class="btn btn-ghost"
                    phx-click="close"
                    phx-target={@myself}
                    id={"#{@id}-cancel"}
                  >
                    Cancel
                  </.button>
                  <.button
                    type="submit"
                    class="btn btn-primary"
                    id={"#{@id}-submit"}
                  >
                    Submit Application
                  </.button>
                </div>
              </div>
            </.form>
          </div>
        </.modal>
      <% end %>
    </div>
    """
  end
end
