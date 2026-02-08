defmodule FosBjjWeb.VideoLive.NewVideoForm do
  use FosBjjWeb, :live_view
  import FosBjjWeb.Components.Drawer
  alias FosBjjWeb.TechniqueLive.NewTechniqueForm
  alias FosBjjWeb.VideoLive.VideoFormComponent

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
      {:ok,
       socket
       |> assign(:show_technique_drawer, false)}
    end
  end

  @impl true
  def handle_event("open_technique_drawer", _, socket) do
    {:noreply, assign(socket, :show_technique_drawer, true)}
  end

  @impl true
  def handle_event("close_technique_drawer", _, socket) do
    {:noreply, assign(socket, :show_technique_drawer, false)}
  end

  @impl true
  def handle_info({:video_saved, _video}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Video added successfully")
     |> push_navigate(to: ~p"/database")}
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
     |> assign(:show_technique_drawer, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]} socket={@socket}>
      <div class="max-w-2xl mx-auto" id="video-form-container">
        <.flash kind={:info} title="Sweet!" flash={@flash} />
        <.flash kind={:error} title="Oops!" flash={@flash} />
        <div class="flex justify-between items-center mb-6">
          <.h1 size="text-3xl" font_weight="font-bold">Add a Video</.h1>
          <.link navigate={~p"/database"} class="btn btn-ghost">
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

      <.drawer
        :if={@show_technique_drawer}
        id="technique-drawer"
        show={@show_technique_drawer}
        on_hide={
          JS.push("close_technique_drawer")
          |> hide_drawer("technique-drawer", "right")
        }
        on_hide_away={
          JS.push("close_technique_drawer")
          |> hide_drawer("technique-drawer", "right")
        }
        position="right"
      >
        <.live_component
          :if={@show_technique_drawer}
          module={NewTechniqueForm}
          id="new-technique-form"
          current_user={@current_user}
        />
      </.drawer>
    </Layouts.app>
    """
  end
end
