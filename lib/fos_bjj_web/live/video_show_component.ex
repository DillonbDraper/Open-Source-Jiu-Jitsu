defmodule FosBjjWeb.VideoShowComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.Video
  import FosBjjWeb.Components.Icon
  import FosBjjWeb.Components.Button
  require Ash.Query

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Only load video if video_id changed or it's the first load
    socket =
      if socket.assigns[:video] == nil or socket.assigns[:video_id] != assigns.video_id do
        load_video(socket, assigns.video_id)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_technique", %{"technique-id" => technique_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/database?technique_id=#{technique_id}")}
  end

  defp load_video(socket, video_id) do
    video =
      Video
      |> Ash.Query.filter(id == ^video_id)
      |> Ash.Query.load(techniques: [:video_count], grips: [])
      |> Ash.read_one!()

    case video do
      nil ->
        socket
        |> put_flash(:error, "Video not found")
        |> push_patch(to: ~p"/database")

      video ->
        assign(socket, :video, video)
    end
  end

  defp youtube_embed_url(video_id) do
    "https://www.youtube.com/embed/#{video_id}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full flex flex-col bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
      <%= if assigns[:video] do %>
        <!-- Back button header -->
        <div class="p-4 border-b border-base-200 bg-base-200/50">
          <.link patch={~p"/database"} class="btn btn-ghost btn-sm gap-2">
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Database
          </.link>
        </div>
        
    <!-- Video Player -->
        <div class="relative w-full" style="padding-bottom: 56.25%;">
          <iframe
            src={youtube_embed_url(@video.video_id)}
            class="absolute top-0 left-0 w-full h-full"
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
          >
          </iframe>
        </div>
        
    <!-- Video Info (matching database card structure) -->
        <div class="flex-1 overflow-y-auto">
          <div class="p-3">
            <h1 class="text-base font-bold mb-1">{@video.title}</h1>
          </div>

          <%= if @video.description do %>
            <p class="text-base-content/70 text-sm line-clamp-2 mb-2 ml-3 whitespace-pre-wrap">
              {@video.description}
            </p>
          <% end %>

          <div class="mt-auto ml-3 mb-3 pt-2 border-t border-base-200 space-y-2">
            <%= if @video.techniques && @video.techniques != [] do %>
              <div class="flex items-start gap-2">
                <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                  Techniques
                </span>
                <div class="flex flex-wrap gap-1.5">
                  <%= for technique <- @video.techniques do %>
                    <.button
                      phx-click="select_technique"
                      phx-target={@myself}
                      phx-value-technique-id={technique.id}
                      size="extra_small"
                      color="primary"
                      rounded="full"
                      variant="default"
                    >
                      {technique.name} ({technique.video_count})
                    </.button>
                  <% end %>
                </div>
              </div>
            <% end %>
            <%= if @video.grips && @video.grips != [] do %>
              <div class="flex items-start gap-2">
                <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                  Grips
                </span>
                <div class="flex flex-wrap gap-1.5">
                  <%= for grip <- @video.grips do %>
                    <span class="px-2 py-0.5 text-xs bg-secondary/20 text-secondary rounded-full border border-secondary/30">
                      {grip.label}
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="flex items-center justify-center h-full">
          <span class="loading loading-spinner loading-lg"></span>
        </div>
      <% end %>
    </div>
    """
  end
end
