defmodule FosBjjWeb.VideoShowComponent do
  use FosBjjWeb, :live_component

  alias FosBjj.JiuJitsu.Video
  alias FosBjj.Accounts.StudentCoachRelationship
  alias FosBjj.Accounts.UserMessage
  alias FosBjj.Accounts.User
  import FosBjjWeb.Components.Icon
  import FosBjjWeb.Components.Button
  import FosBjjWeb.Components.Authorization
  require Ash.Query

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :current_time, 0)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # This feels wrong but I'm not sure how else it ought be done
    socket =
      if Map.has_key?(socket.assigns, :show_info),
        do: socket,
        else: assign(socket, :show_info, true)

    socket =
      if Map.has_key?(socket.assigns, :show_notes),
        do: socket,
        else: assign(socket, :show_notes, true)

    socket =
      if Map.has_key?(socket.assigns, :show_share_modal),
        do: socket,
        else: assign(socket, :show_share_modal, false)

    socket =
      if Map.has_key?(socket.assigns, :share_form),
        do: socket,
        else: assign(socket, :share_form, to_form(%{"message" => ""}))

    # Load student count for coaches/admins
    socket =
      if Map.has_key?(socket.assigns, :student_count) do
        socket
      else
        user = socket.assigns[:current_user]
        count = if user && User.coach_or_admin?(user), do: get_student_count(user), else: 0
        assign(socket, :student_count, count)
      end

    socket =
      if assigns[:seek_time] do
        push_event(socket, "seek", %{seconds: assigns.seek_time})
      else
        socket
      end

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
    {:noreply, assign(socket, :current_time, rounded_time)}
  end

  @impl true
  def handle_event("open_share_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, true)
     |> assign(:share_form, to_form(%{"message" => ""}))}
  end

  @impl true
  def handle_event("close_share_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> assign(:share_form, to_form(%{"message" => ""}))}
  end

  @impl true
  def handle_event("update_share_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :share_form, to_form(%{"message" => message}))}
  end

  @impl true
  def handle_event("share_video", %{"message" => message}, socket) do
    user = socket.assigns.current_user
    video = socket.assigns.video

    # This is somewhat brittle as share_video_with_students/3 doesn't really error handle
    with {:ok, count} <- share_video_with_students(user, video, message) do
      {:noreply,
       socket
       |> assign(:show_share_modal, false)
       |> assign(:share_form, to_form(%{"message" => ""}))
       |> put_flash(:info, "Video shared with #{count} student(s)")}
    end
  end

  defp get_student_count(coach) do
    StudentCoachRelationship
    |> Ash.Query.filter(coach_id == ^coach.id)
    |> Ash.read!(actor: coach)
    |> length()
  end

  defp share_video_with_students(coach, video, optional_message) do
    students =
      StudentCoachRelationship
      |> Ash.Query.filter(coach_id == ^coach.id)
      |> Ash.Query.load(:learner)
      |> Ash.read!(actor: coach)
      |> Enum.map(& &1.learner)

    message =
      case optional_message do
        text when is_binary(text) ->
          if String.trim(text) == "", do: nil, else: text

        _ ->
          nil
      end

    Enum.each(students, fn student ->
      UserMessage
      |> Ash.Changeset.for_create(
        :send,
        %{
          body: message,
          recipient_id: student.id,
          shared_video_id: video.id
        },
        actor: coach
      )
      |> Ash.create!()
    end)

    {:ok, length(students)}
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
          <.button_link
            patch={~p"/database"}
            variant="transparent"
            color="base"
            size="small"
            icon="hero-arrow-left"
            icon_class="w-4 h-4"
          >
            Back to Database
          </.button_link>

          <%= if @current_user && User.coach_or_admin?(@current_user) do %>
            <.tooltip id="share-video-tooltip" position="left" color="dark">
              <:trigger>
                <.button
                  id="share-video-button"
                  type="button"
                  phx-click={if @student_count > 0, do: "open_share_modal"}
                  phx-target={@myself}
                  disabled={@student_count == 0}
                  variant="default"
                  color="primary"
                  size="small"
                  circle
                  icon="hero-radio"
                  icon_class="w-5 h-5"
                  class={if @student_count == 0, do: "cursor-not-allowed opacity-70", else: ""}
                />
              </:trigger>
              <:content>
                <%= if @student_count > 0 do %>
                  Share this Video To Your Students
                <% else %>
                  You must have students following you to broadcast videos
                <% end %>
              </:content>
            </.tooltip>
          <% end %>
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
          <.verified_user_only current_user={@current_user}>
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
          </.verified_user_only>
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
                          <.badge variant="outline" color="secondary" size="extra_small" class="px-2">
                            {grip.label}
                          </.badge>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <.modal
          :if={@show_share_modal}
          show
          id="share-video-modal"
          size="large"
          on_cancel={JS.push("close_share_modal", target: @myself)}
        >
          <div class="space-y-4">
            <.h3 class="text-xl font-semibold">Share Video with Your Students</.h3>

            <div class="bg-base-200 rounded-lg p-3">
              <.p class="text-sm text-base-content/70">Sharing:</.p>
              <.p class="font-medium">{@video.title}</.p>
            </div>

            <.form
              for={@share_form}
              id="share-video-form"
              phx-change="update_share_message"
              phx-submit="share_video"
              phx-target={@myself}
              class="space-y-4"
            >
              <.textarea_field
                id={"#{@id}-share-message"}
                field={@share_form[:message]}
                label="Add a message (optional)"
                placeholder="Add a note about this video..."
                rows="3"
                class="w-full"
              />

              <div class="flex justify-end gap-2">
                <.button
                  type="button"
                  phx-click="close_share_modal"
                  phx-target={@myself}
                  variant="transparent"
                  color="base"
                >
                  Cancel
                </.button>
                <.button
                  type="submit"
                  variant="default"
                  color="primary"
                  icon="hero-paper-airplane"
                  icon_class="w-4 h-4"
                >
                  Share with Students
                </.button>
              </div>
            </.form>
          </div>
        </.modal>
      <% else %>
        <div class="flex items-center justify-center h-64">
          <.spinner size="large" color="primary" />
        </div>
      <% end %>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".YouTubeSeeker">
                export default {
                mounted() {
        this.videoId = this.el.dataset.videoId;
        this.pendingSeek = null;
        this.playerReady = false;
        this.loadYouTubeAPI();

        this.handleEvent("seek", ({ seconds }) => {
          if (this.playerReady && this.player && typeof this.player.seekTo === 'function') {
            this.player.seekTo(seconds, true);
          } else {
            this.pendingSeek = seconds;
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
            },
            events: {
              'onReady': (event) => {
                this.playerReady = true;
                if (this.pendingSeek !== null) {
                  event.target.seekTo(this.pendingSeek, true);
                  this.pendingSeek = null;
                }
              }
            }
            });
            }
                }
      </script>
    </div>
    """
  end
end
