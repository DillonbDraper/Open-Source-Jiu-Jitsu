defmodule FosBjjWeb.VideoShowComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.Video
  import FosBjjWeb.Components.Icon
  import FosBjjWeb.Components.Button
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :current_time, 0)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if Map.has_key?(socket.assigns, :show_info),
        do: socket,
        else: assign(socket, :show_info, true)

    socket =
      if Map.has_key?(socket.assigns, :show_notes),
        do: socket,
        else: assign(socket, :show_notes, true)

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

  @impl true
  def handle_event("toggle_info", _, socket) do
    {:noreply, update(socket, :show_info, &(!&1))}
  end

  @impl true
  def handle_event("toggle_notes", _, socket) do
    {:noreply, update(socket, :show_notes, &(!&1))}
  end

  @impl true
  def handle_event("player_status_report", %{"current_time" => time}, socket) do
    rounded_time = floor(time)
    IO.inspect(rounded_time)
    {:noreply, assign(socket, :current_time, rounded_time)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full flex flex-col gap-6 pb-8">
      <%= if assigns[:video] do %>
        <div class="flex items-center justify-between">
          <.link patch={~p"/database"} class="btn btn-ghost btn-sm gap-2">
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Database
          </.link>
        </div>

        <div
          id="video-player-container"
          class="bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden"
        >
          <div class="relative w-full" style="padding-bottom: 56.25%;">
            <div
              id={"#{@id}-player-wrapper"}
              phx-hook=".YouTubeSeeker"
              phx-update="ignore"
              data-video-id={@video.video_id}
              data-player-id={"#{@id}-player-target"}
              class="absolute top-0 left-0 w-full h-full"
            >
              <div id={"#{@id}-player-target"}></div>
            </div>
          </div>
        </div>

        <div id="video-sections-container" class="flex flex-col gap-6">
          <%= if @current_user do %>
            <div class="bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
              <div
                class="p-3 bg-base-200/50 border-b border-base-200 flex justify-between items-center cursor-pointer hover:bg-base-200 transition-colors select-none"
                phx-click="toggle_notes"
                phx-target={@myself}
              >
                <h2 class="font-bold text-sm uppercase tracking-wide text-base-content/70">
                  My Notes
                </h2>
                <.icon
                  name={if @show_notes, do: "hero-chevron-up", else: "hero-chevron-down"}
                  class="w-5 h-5 text-base-content/50"
                />
              </div>

              <%= if @show_notes do %>
                <div class="p-4">
                  <.live_component
                    module={FosBjjWeb.VideoNotesComponent}
                    id="video-notes"
                    video_id={@video.id}
                    current_user={@current_user}
                    current_time={@current_time}
                  />
                </div>
              <% end %>
            </div>
          <% end %>
          <div class="bg-base-100 rounded-lg shadow-lg border border-base-200 overflow-hidden">
            <div
              class="p-3 bg-base-200/50 border-b border-base-200 flex justify-between items-center cursor-pointer hover:bg-base-200 transition-colors select-none"
              phx-click="toggle_info"
              phx-target={@myself}
            >
              <h2 class="font-bold text-sm uppercase tracking-wide text-base-content/70">
                Video Information
              </h2>
              <.icon
                name={if @show_info, do: "hero-chevron-up", else: "hero-chevron-down"}
                class="w-5 h-5 text-base-content/50"
              />
            </div>

            <%= if @show_info do %>
              <div class="p-4">
                <h1 class="text-xl font-bold mb-4">{@video.title}</h1>

                <%= if @video.description do %>
                  <div class="prose prose-sm max-w-none mb-6">
                    {@video.description}
                  </div>
                <% end %>

                <div class="space-y-4 pt-4 border-t border-base-200">
                  <%= if @video.techniques && @video.techniques != [] do %>
                    <div class="flex items-start gap-3">
                      <span class="text-xs font-bold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                        Techniques
                      </span>
                      <div class="flex flex-wrap gap-2">
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
                    <div class="flex items-start gap-3">
                      <span class="text-xs font-bold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                        Grips
                      </span>
                      <div class="flex flex-wrap gap-2">
                        <%= for grip <- @video.grips do %>
                          <span class="px-2 py-1 text-xs font-medium bg-secondary/10 text-secondary rounded-md border border-secondary/20">
                            {grip.label}
                          </span>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="flex items-center justify-center h-64">
          <span class="loading loading-spinner loading-lg"></span>
        </div>
      <% end %>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".YouTubeSeeker">
                export default {
                mounted() {
        this.videoId = this.el.dataset.videoId;
        this.loadYouTubeAPI();

        this.handleEvent("seek", ({ seconds }) => {
          if (this.player && this.player.seekTo) {
            this.player.seekTo(seconds, true);
          }
        });

        this.handleEvent("request_player_status", () => {
          if (!this.player || !this.player.getCurrentTime) return;
          this.player.pauseVideo();

          const currentTime = this.player.getCurrentTime();

          // Send result back to the specific component that owns this hook
          // 'player_status_report' must match handle_event in the Elixir component
          this.pushEventTo(this.el, "player_status_report", {
            current_time: currentTime
          });
        });
        },

                destroyed() {
                  if (this.player) this.player.destroy();
                },

                loadYouTubeAPI() {
                  // If API is ready, init immediately
                  if (window.YT && window.YT.Player) {
                    this.initPlayer();
                    return;
                  }

                  // Standard queueing mechanism for the async script load
                  window.onYouTubeIframeAPIReady = window.onYouTubeIframeAPIReady || [];
                  const existingCallback = window.onYouTubeIframeAPIReady;

                  window.onYouTubeIframeAPIReady = () => {
                    if (existingCallback && typeof existingCallback === 'function') existingCallback();
                    this.initPlayer();
                  };

                  if (!document.getElementById("youtube-api-script")) {
                    const tag = document.createElement('script');
                    tag.id = "youtube-api-script";
                    tag.src = "https://www.youtube.com/iframe_api";
                    document.head.appendChild(tag);
                  }
                },

                initPlayer() {
            // We grab the ID of the sacrificial child div
            const playerId = this.el.dataset.playerId;

            this.player = new YT.Player(playerId, { // <--- Use the child ID here
            videoId: this.videoId,
            height: '100%', // Ensure the iframe fills the wrapper
            width: '100%',
            playerVars: {
              'playsinline': 1,
              'modestbranding': 1
            }
            });
            }
                }
      </script>
    </div>
    """
  end
end
