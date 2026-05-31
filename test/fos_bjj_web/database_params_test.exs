defmodule FosBjjWeb.DatabaseParamsTest do
  use FosBjj.DataCase, async: true

  alias FosBjjWeb.DatabaseParams

  test "normalizes inAction video type" do
    assert DatabaseParams.normalize_video_type("in_action") == "in_action"
  end

  test "build preserves inAction video type in query params" do
    assert [video_type: "in_action"] =
             DatabaseParams.build(%{}, selected_video_type: "in_action")
  end
end
