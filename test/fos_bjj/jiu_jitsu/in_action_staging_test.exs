defmodule FosBjj.JiuJitsu.InActionStagingTest do
  use FosBjj.DataCase, async: true

  import FosBjj.Fixtures

  alias FosBjj.JiuJitsu.InActionStaging

  test "create accepts ranges of 15 seconds or less" do
    user = user_fixture()
    video = video_fixture(%{user: user})

    assert {:ok, staging} =
             Ash.create(
               InActionStaging,
               %{
                 video_id: video.id,
                 source_url: "https://www.youtube.com/watch?v=abc123",
                 source_video_id: "abc123",
                 start_seconds: 10,
                 end_seconds: 25
               },
               action: :create,
               actor: user
             )

    assert staging.start_seconds == 10
    assert staging.end_seconds == 25
    assert staging.status == :pending
  end

  test "create rejects ranges longer than 15 seconds" do
    user = user_fixture()
    video = video_fixture(%{user: user})

    assert {:error, error} =
             Ash.create(
               InActionStaging,
               %{
                 video_id: video.id,
                 source_url: "https://www.youtube.com/watch?v=abc123",
                 source_video_id: "abc123",
                 start_seconds: 10,
                 end_seconds: 26
               },
               action: :create,
               actor: user
             )

    assert Exception.message(error) =~ "15 seconds or shorter"
  end

  test "create rejects ranges where the end is not after the start" do
    user = user_fixture()
    video = video_fixture(%{user: user})

    assert {:error, error} =
             Ash.create(
               InActionStaging,
               %{
                 video_id: video.id,
                 source_url: "https://www.youtube.com/watch?v=abc123",
                 source_video_id: "abc123",
                 start_seconds: 10,
                 end_seconds: 10
               },
               action: :create,
               actor: user
             )

    assert Exception.message(error) =~ "greater than start"
  end
end
