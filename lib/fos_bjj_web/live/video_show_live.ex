defmodule FosBjjWeb.VideoShowLive do
  use FosBjjWeb, :live_view

  alias FosBjj.JiuJitsu.Video
  alias FosBjjWeb.CoreComponents
  import FosBjjWeb.Components.Card
  import FosBjjWeb.Components.Button
  require Ash.Query

  on_mount {FosBjjWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    video =
      Video
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.load([:techniques, :grips])
      |> Ash.read_one!()

    case video do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Video not found")
         |> push_navigate(to: ~p"/database")}

      video ->
        {:ok,
         socket
         |> assign(:video, video)
         |> assign(:selected_technique_id, nil)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    technique_id = params["technique_id"]

    {:noreply, assign(socket, :selected_technique_id, technique_id)}
  end

  @impl true
  def handle_event("select_technique", %{"technique-id" => technique_id}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/videos/#{socket.assigns.video.id}?technique_id=#{technique_id}")}
  end

  defp youtube_embed_url(video_id) do
    "https://www.youtube.com/embed/#{video_id}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="flex flex-row h-[calc(100vh-8rem)] gap-4">
        <!-- Left Side: Video Player & Info (50-60%) -->
        <div class="w-3/5 min-w-[50%] h-full flex flex-col gap-4">
          <!-- Back button -->
          <div class="flex items-center gap-2">
            <.link navigate={~p"/database"} class="btn btn-ghost btn-sm gap-2">
              <CoreComponents.icon name="hero-arrow-left" class="w-4 h-4" />
              Back to Database
            </.link>
          </div>

          <!-- Video Player Card -->
          <.card class="flex-1 flex flex-col overflow-hidden">
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

            <.card_content class="flex-1 p-6 overflow-y-auto">
              <h1 class="text-2xl font-bold mb-3">{@video.title}</h1>

              <%= if @video.description do %>
                <p class="text-base-content/80 mb-4 whitespace-pre-wrap">{@video.description}</p>
              <% end %>

              <div class="flex items-center gap-2 mb-4">
                <span class="text-sm font-medium text-base-content/70">Attire:</span>
                <span class={[
                  "badge",
                  @video.attire == :gi && "badge-primary",
                  @video.attire == :no_gi && "badge-secondary"
                ]}>
                  {String.upcase(to_string(@video.attire))}
                </span>
              </div>

              <div class="border-t border-base-200 pt-4 space-y-3">
                <%= if @video.techniques && @video.techniques != [] do %>
                  <div class="flex items-start gap-2">
                    <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wide pt-1 min-w-[80px]">
                      Techniques
                    </span>
                    <div class="flex flex-wrap gap-2">
                      <%= for technique <- @video.techniques do %>
                        <.button
                          phx-click="select_technique"
                          phx-value-technique-id={technique.id}
                          size="extra_small"
                          color="primary"
                          rounded="full"
                          variant="default"
                        >
                          {technique.name}
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
            </.card_content>
          </.card>
        </div>

        <!-- Right Side: Technique Tree (40-50%) -->
        <div class="w-2/5 flex-1 h-full">
          <.live_component
            module={FosBjjWeb.TechniqueTreeComponent}
            id="technique-tree"
            selected_technique_id={@selected_technique_id}
            target_route={~p"/videos/#{@video.id}"}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
