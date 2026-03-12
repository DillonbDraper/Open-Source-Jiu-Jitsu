defmodule FosBjjWeb.VideoReportModalComponentTest do
  use FosBjjWeb.ConnCase, async: true

  import FosBjj.Fixtures
  import Phoenix.LiveViewTest

  alias FosBjj.Accounts.UserVideoReport
  alias FosBjj.Accounts.VideoReportReason
  alias FosBjj.ConfigData
  require Ash.Query

  setup do
    :ok = ConfigData.sync(VideoReportReason)
    :ok
  end

  defmodule HostLive do
    use FosBjjWeb, :live_view

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:current_user, Map.get(session, "current_user"))
       |> Phoenix.Component.assign(:video, Map.get(session, "video"))}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={FosBjjWeb.VideoReportModalComponent}
          id="video-report-modal-component"
          current_user={@current_user}
          video={@video}
        />
      </div>
      """
    end
  end

  test "does not render report action for guests", %{conn: conn} do
    video = video_fixture()

    {:ok, view, _html} =
      live_isolated(conn, HostLive, session: %{"current_user" => nil, "video" => video})

    refute has_element?(view, "#report-video-button")
  end

  test "renders report modal with no default reason selected", %{conn: conn} do
    user = user_fixture(%{confirmed: true})
    video = video_fixture()

    {:ok, view, _html} =
      live_isolated(conn, HostLive, session: %{"current_user" => user, "video" => video})

    assert has_element?(view, "#report-video-button")

    view
    |> element("#report-video-button")
    |> render_click()

    assert has_element?(view, "#report-video-modal")

    assert has_element?(
             view,
             "#report-video-form select[name='reason_name'] option[value=''][selected][disabled]"
           )
  end

  test "submit requires reason and valid submit creates report", %{conn: conn} do
    user = user_fixture(%{confirmed: true})
    video = video_fixture()

    {:ok, view, _html} =
      live_isolated(conn, HostLive, session: %{"current_user" => user, "video" => video})

    view
    |> element("#report-video-button")
    |> render_click()

    view
    |> element("#report-video-form")
    |> render_submit(%{"reason_name" => "", "message" => "No reason selected"})

    assert [] == list_reports_for_video(user, video.id)

    view
    |> element("#report-video-form")
    |> render_submit(%{"reason_name" => "broken_link", "message" => "Video does not load"})

    reports = list_reports_for_video(user, video.id)
    assert length(reports) == 1

    report = List.first(reports)
    assert report.reason_name == "broken_link"
    assert report.message == "Video does not load"
  end

  defp list_reports_for_video(actor, video_id) do
    UserVideoReport
    |> Ash.Query.filter(user_id == ^actor.id and video_id == ^video_id)
    |> Ash.read!(actor: actor)
  end
end
