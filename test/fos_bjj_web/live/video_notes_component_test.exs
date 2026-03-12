defmodule FosBjjWeb.VideoNotesComponentTest do
  use FosBjjWeb.ConnCase, async: true

  import FosBjj.Fixtures
  import Phoenix.LiveViewTest

  alias FosBjj.JiuJitsu.VideoNote

  defmodule HostLive do
    use FosBjjWeb, :live_view

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:current_user, session["current_user"])
       |> Phoenix.Component.assign(:video, session["video"])
       |> Phoenix.Component.assign(:current_time, session["current_time"] || 0)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={FosBjjWeb.VideoNotesComponent}
          id="video-notes"
          video_id={@video.id}
          current_user={@current_user}
          current_time={@current_time}
        />
      </div>
      """
    end
  end

  defmodule DashboardHostLive do
    use FosBjjWeb, :live_view

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:current_user, session["current_user"])
       |> Phoenix.Component.assign(:video, session["video"])
       |> Phoenix.Component.assign(:current_time, 0)}
    end

    @impl true
    def handle_info({:player_time_update, time}, socket) do
      {:noreply, Phoenix.Component.assign(socket, :current_time, time)}
    end

    @impl true
    def handle_info({:seek_video, seconds}, socket) do
      send_update(FosBjjWeb.VideoShowComponent,
        id: "video-show-component",
        seek_seconds: seconds
      )

      {:noreply, socket}
    end

    @impl true
    def handle_info({:request_player_status}, socket) do
      send_update(FosBjjWeb.VideoShowComponent,
        id: "video-show-component",
        request_status: true
      )

      {:noreply, socket}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={FosBjjWeb.VideoShowComponent}
          id="video-show-component"
          video_id={@video.id}
          current_user={@current_user}
          selected_technique_id={nil}
          seek_time={nil}
        />

        <.live_component
          module={FosBjjWeb.VideoNotesComponent}
          id="video-notes"
          video_id={@video.id}
          current_user={@current_user}
          current_time={@current_time}
        />
      </div>
      """
    end
  end

  test "clicking a collapsed note expands and collapses it", %{conn: conn} do
    user = user_fixture(%{confirmed: true})
    video = video_fixture(%{user: user})
    note = create_note!(user, video, %{body: "This note should expand", video_timestamp: 42})

    {:ok, view, _html} =
      live_isolated(conn, HostLive, session: %{"current_user" => user, "video" => video})

    collapsed_selector = "button[phx-click=\"toggle_note\"][phx-value-id=\"#{note.id}\"]"
    expanded_selector = "button[phx-click=\"delete_note\"][phx-value-id=\"#{note.id}\"]"

    assert has_element?(view, collapsed_selector)
    refute has_element?(view, expanded_selector)

    view
    |> element(collapsed_selector)
    |> render_click()

    assert has_element?(view, "button[phx-click=\"collapse_note\"]")
    assert has_element?(view, expanded_selector)
    refute has_element?(view, collapsed_selector)

    view
    |> element("button[phx-click=\"collapse_note\"][phx-value-id=\"#{note.id}\"]")
    |> render_click()

    assert has_element?(view, collapsed_selector)
    refute has_element?(view, expanded_selector)
  end

  test "clicking timestamp seeks without collapsing expanded note", %{conn: conn} do
    user = user_fixture(%{confirmed: true})
    video = video_fixture(%{user: user})
    note = create_note!(user, video, %{body: "Timestamp target note", video_timestamp: 51})

    {:ok, view, _html} =
      live_isolated(conn, DashboardHostLive, session: %{"current_user" => user, "video" => video})

    collapsed_selector = "button[phx-click=\"toggle_note\"][phx-value-id=\"#{note.id}\"]"
    expanded_selector = "button[phx-click=\"delete_note\"][phx-value-id=\"#{note.id}\"]"
    timestamp_selector = "button[phx-click=\"seek_video\"][phx-value-seconds=\"51\"]"

    view
    |> element(collapsed_selector)
    |> render_click()

    assert has_element?(view, expanded_selector)

    view
    |> element(timestamp_selector)
    |> render_click()

    assert has_element?(view, expanded_selector)
    assert has_element?(view, "button[phx-click=\"collapse_note\"][phx-value-id=\"#{note.id}\"]")
  end

  test "multiple notes can be expanded and collapsed independently", %{conn: conn} do
    user = user_fixture(%{confirmed: true})
    video = video_fixture(%{user: user})

    note_one = create_note!(user, video, %{body: "First note", video_timestamp: 10})
    note_two = create_note!(user, video, %{body: "Second note", video_timestamp: 20})

    {:ok, view, _html} =
      live_isolated(conn, HostLive, session: %{"current_user" => user, "video" => video})

    toggle_one = "button[phx-click=\"toggle_note\"][phx-value-id=\"#{note_one.id}\"]"
    toggle_two = "button[phx-click=\"toggle_note\"][phx-value-id=\"#{note_two.id}\"]"
    expanded_one = "button[phx-click=\"delete_note\"][phx-value-id=\"#{note_one.id}\"]"
    expanded_two = "button[phx-click=\"delete_note\"][phx-value-id=\"#{note_two.id}\"]"

    view
    |> element(toggle_one)
    |> render_click()

    view
    |> element(toggle_two)
    |> render_click()

    assert has_element?(view, expanded_one)
    assert has_element?(view, expanded_two)

    view
    |> element("button[phx-click=\"collapse_note\"][phx-value-id=\"#{note_one.id}\"]")
    |> render_click()

    refute has_element?(view, expanded_one)
    assert has_element?(view, expanded_two)
  end

  defp create_note!(user, video, attrs) do
    defaults = %{video_id: video.id, body: "Note body", video_timestamp: nil}

    Ash.create!(VideoNote, Map.merge(defaults, attrs), action: :create, actor: user)
  end
end
