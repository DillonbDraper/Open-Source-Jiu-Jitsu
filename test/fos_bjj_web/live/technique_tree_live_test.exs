defmodule FosBjjWeb.TechniqueTreeLiveTest do
  use FosBjjWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FosBjj.Fixtures

  test "expands the tree and loads techniques", %{conn: conn} do
    data = position_tree_fixture()

    {:ok, view, _html} = live(conn, "/database")

    assert has_element?(view, "#technique-tree-scroll")

    view
    |> element("button[phx-value-level=position][phx-value-pos=\"#{data.position_name}\"]")
    |> render_click()

    assert has_element?(
             view,
             "button[phx-value-level=orientation][phx-value-ori=\"#{data.orientation_name}\"]"
           )

    view
    |> element(
      "button[phx-value-level=orientation][phx-value-pos=\"#{data.position_name}\"][phx-value-ori=\"#{data.orientation_name}\"]"
    )
    |> render_click()

    assert has_element?(
             view,
             "button[phx-value-level=sub_position][phx-value-sub=\"#{data.sub_position_name}\"]"
           )

    view
    |> element(
      "button[phx-value-level=sub_position][phx-value-sub=\"#{data.sub_position_name}\"]"
    )
    |> render_click()

    assert has_element?(
             view,
             "button[phx-value-level=action][phx-value-action=\"#{data.action_with_technique}\"]"
           )

    assert has_element?(
             view,
             "button[phx-value-level=action][phx-value-action=\"#{data.action_without_technique}\"]"
           )

    view
    |> element(
      "button[phx-value-level=action][phx-value-action=\"#{data.action_with_technique}\"]"
    )
    |> render_click()

    assert has_element?(view, "a", "#{data.technique.name} (1)")

    view
    |> element(
      "button[phx-value-level=action][phx-value-action=\"#{data.action_without_technique}\"]"
    )
    |> render_click()

    assert has_element?(view, "span", "No techniques found")
  end

  test "filter events push patches", %{conn: conn} do
    _data = position_tree_fixture()

    {:ok, view, _html} = live(conn, "/database")

    view
    |> form("form[phx-change=attire_change]", %{"attire" => "gi"})
    |> render_change()

    assert_patch(view, "/database?attire=gi")

    view
    |> form("form[phx-submit=title_search]", %{"title" => "armbar"})
    |> render_submit()

    assert_patch(view, "/database?title=armbar&attire=gi")

    view
    |> element("button[phx-click=clear_all]")
    |> render_click()

    assert_patch(view, "/database?attire=both")
  end
end
