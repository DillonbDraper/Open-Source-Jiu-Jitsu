defmodule FosBjjWeb.VideoLive.NewVideoForm do
  use FosBjjWeb, :live_view
  import FosBjjWeb.Components.Drawer
  alias FosBjjWeb.TechniqueLive.NewTechniqueForm
  alias FosBjjWeb.VideoLive.{InActionVideoFormComponent, VideoFormComponent}

  on_mount({AshAuthentication.Phoenix.LiveSession, {:live_user_required, otp_app: :fos_bjj}})

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:show_technique_drawer, false)
      |> assign(:form_mode, :normal)

    unless FosBjj.Accounts.User.contributor_or_admin?(current_user) do
      {:ok,
       socket
       |> put_flash(:danger, "You must be a contributor or admin to add videos")
       |> push_navigate(to: ~p"/")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_form_mode", %{"mode" => "in_action"}, socket) do
    {:noreply, assign(socket, :form_mode, :in_action)}
  end

  @impl true
  def handle_event("select_form_mode", %{"mode" => "normal"}, socket) do
    {:noreply, assign(socket, :form_mode, :normal)}
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
  def handle_info({:video_saved, video}, socket) do
    message =
      if video.video_type_name == "in_action",
        do: "inAction video staged successfully",
        else: "Video added successfully"

    {:noreply,
     socket
     |> put_flash(:success, message)
     |> push_navigate(to: ~p"/database")}
  end

  @impl true
  def handle_info({NewTechniqueForm, {:technique_created, technique}}, socket) do
    {component, component_id} =
      case socket.assigns.form_mode do
        :in_action -> {InActionVideoFormComponent, "in-action-video-form-component"}
        :normal -> {VideoFormComponent, "video-form-component"}
      end

    send_update(component,
      id: component_id,
      action: :technique_created,
      technique: technique
    )

    {:noreply,
     socket
     |> put_flash(:success, "Technique created successfully")
     |> assign(:show_technique_drawer, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]} socket={@socket}>
      <div class="max-w-2xl mx-auto" id="video-form-container">
        <div class="flex flex-col gap-4 mb-6 sm:flex-row sm:items-start sm:justify-between">
          <div class="space-y-1">
            <.h1 size="text-3xl" font_weight="font-bold">Add a Video</.h1>
            <.p size="text-sm" class="text-base-content/70">
              Choose a standard technique/analysis video or stage a short inAction clip.
            </.p>
          </div>

          <div class="flex flex-wrap items-center justify-end gap-3">
            <div
              id="video-form-mode-toggle"
              class="inline-flex rounded-full border border-base-300 bg-base-100 p-1 shadow-sm"
            >
              <.button
                id="normal-video-toggle"
                type="button"
                variant={if(@form_mode == :normal, do: "default", else: "transparent")}
                color={if(@form_mode == :normal, do: "primary", else: "natural")}
                border="none"
                rounded="full"
                size="small"
                font_weight="font-semibold"
                phx-click="select_form_mode"
                phx-value-mode="normal"
                class="px-4 py-2 text-sm transition"
              >
                Technique / Analysis
              </.button>
              <.button
                id="in-action-video-toggle"
                type="button"
                variant={if(@form_mode == :in_action, do: "default", else: "transparent")}
                color={if(@form_mode == :in_action, do: "primary", else: "natural")}
                border="none"
                rounded="full"
                size="small"
                font_weight="font-semibold"
                phx-click="select_form_mode"
                phx-value-mode="in_action"
                class="px-4 py-2 text-sm transition"
              >
                inAction
              </.button>
            </div>

            <.link navigate={~p"/database"} class="btn btn-ghost">
              ← Back
            </.link>
          </div>
        </div>

        <%= if @form_mode == :in_action do %>
          <.live_component
            module={InActionVideoFormComponent}
            id="in-action-video-form-component"
            current_user={@current_user}
            on_cancel={JS.navigate(~p"/")}
          />
        <% else %>
          <.live_component
            module={VideoFormComponent}
            id="video-form-component"
            current_user={@current_user}
            video={nil}
            on_cancel={JS.navigate(~p"/")}
          />
        <% end %>
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
