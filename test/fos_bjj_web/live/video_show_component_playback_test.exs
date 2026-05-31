defmodule FosBjjWeb.VideoShowComponentPlaybackTest do
  use FosBjjWeb.ConnCase, async: true

  import FosBjj.Fixtures
  import Phoenix.LiveViewTest

  alias FosBjj.ConfigData
  alias FosBjj.JiuJitsu.VideoType

  defmodule HostLive do
    use FosBjjWeb, :live_view

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:current_user, session["current_user"])
       |> Phoenix.Component.assign(:video, session["video"])}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={FosBjjWeb.VideoShowComponent}
          id="video-show-component"
          video_id={@video.id}
          selected_technique_id={nil}
          current_user={@current_user}
          seek_time={nil}
        />
      </div>
      """
    end
  end

  setup do
    :ok = ConfigData.sync(VideoType)
    :ok
  end

  test "hosted videos render with the Mishka video component", %{conn: conn} do
    user = user_fixture(%{confirmed: true})

    video =
      video_fixture(%{
        user: user,
        video_type_name: "in_action",
        source_type: :hosted,
        hosted_video_url: "https://cdn.example.com/in-action.mp4"
      })

    {:ok, view, _html} =
      live_isolated(conn, HostLive, session: %{"current_user" => user, "video" => video})

    assert has_element?(view, "#video-show-component-hosted-player")

    assert has_element?(
             view,
             "#video-show-component-hosted-player source[src='https://cdn.example.com/in-action.mp4'][type='video/mp4']"
           )
  end
end
