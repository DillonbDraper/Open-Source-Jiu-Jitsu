defmodule FosBjjWeb.VideoLive.NewVideoForm do
  use FosBjjWeb, :live_view
  alias FosBjjWeb.VideoLive.VideoFormComponent
  alias FosBjjWeb.TechniqueLive.NewTechniqueForm

  on_mount({AshAuthentication.Phoenix.LiveSession, {:live_user_required, otp_app: :fos_bjj}})

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    unless FosBjj.Accounts.User.coach_or_admin?(current_user) do
      {:ok,
       socket
       |> put_flash(:error, "You must be a coach or admin to add videos")
       |> push_navigate(to: ~p"/")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info({:video_saved, _video}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Video added successfully")
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def handle_info({NewTechniqueForm, {:technique_created, technique}}, socket) do
    # Forward the message to the component by sending an update
    send_update(VideoFormComponent,
      id: "video-form-component",
      action: :technique_created,
      technique: technique
    )

    {:noreply,
     socket
     |> put_flash(:info, "Technique created successfully")
     |> push_event("js-exec", %{to: "#technique-drawer-video-form-component", attr: "phx-remove"})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="max-w-2xl mx-auto" id="video-form-container" phx-hook=".JsExec">
        <.flash kind={:info} title="Success" flash={@flash} />
        <.flash kind={:error} title="Error" flash={@flash} />
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-3xl font-bold">Add New Video</h1>
          <.link navigate={~p"/"} class="btn btn-ghost">
            ← Back
          </.link>
        </div>

        <.live_component
          module={VideoFormComponent}
          id="video-form-component"
          current_user={@current_user}
          video={nil}
          on_cancel={JS.navigate(~p"/")}
        />
      </div>

      <%!-- Colocated hook for executing JS to close drawer w/animation --%>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".JsExec">
        export default {
          mounted() {
            this.handleEvent("js-exec", ({ to, attr }) => {
              document.querySelectorAll(to).forEach((el) => {
                this.liveSocket.execJS(el, el.getAttribute(attr));
              });
            });
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
