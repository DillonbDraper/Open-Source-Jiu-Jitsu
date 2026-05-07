defmodule FosBjjWeb.VideoShareFlashTest do
  use FosBjjWeb.ConnCase, async: true

  import FosBjj.Fixtures
  import Phoenix.LiveViewTest

  alias FosBjj.Accounts.StudentCoachRelationship
  alias FosBjj.Accounts.UserMessage

  require Ash.Query

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
    def handle_info({:video_share_flash, kind, message}, socket) do
      {:noreply, Phoenix.LiveView.put_flash(socket, kind, message)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        <Layouts.flash_group flash={@flash} />

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

  test "sharing video shows success flash from parent liveview", %{conn: conn} do
    coach = user_fixture(%{role: "coach", confirmed: true})
    learner = user_fixture(%{role: "student", confirmed: true})
    video = video_fixture(%{user: coach})

    Ash.create!(
      StudentCoachRelationship,
      %{coach_id: coach.id},
      action: :follow,
      actor: learner
    )

    {:ok, view, _html} =
      live_isolated(conn, HostLive, session: %{"current_user" => coach, "video" => video})

    view
    |> element("#share-video-button")
    |> render_click()

    assert has_element?(view, "#share-video-modal")

    view
    |> form("#share-video-form", %{"message" => "Watch this before class"})
    |> render_submit()

    refute has_element?(view, "#share-video-modal")

    assert has_element?(view, "#flash-bordered-success", "Video shared with 1 student(s)")

    shared_message_count =
      UserMessage
      |> Ash.Query.filter(recipient_id == ^learner.id and shared_video_id == ^video.id)
      |> Ash.read!(actor: learner)
      |> length()

    assert shared_message_count == 1
  end
end
