defmodule FosBjj.JiuJitsu.InActionVideosTest do
  use FosBjj.DataCase, async: true
  use Oban.Testing, repo: FosBjj.Repo

  import FosBjj.Fixtures

  alias FosBjj.ConfigData
  alias FosBjj.JiuJitsu.{InActionStaging, VideoType}
  alias FosBjj.Workers.ProcessInActionVideo

  require Ash.Query

  setup do
    :ok = ConfigData.sync(VideoType)
    :ok
  end

  test "create_in_action_video creates the video, staging row, and processing job" do
    user = user_fixture()

    assert {:ok, video} =
             FosBjj.JiuJitsu.create_in_action_video(
               %{
                 "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                 "title" => "Mounted armbar inAction",
                 "attire" => "gi",
                 "start_seconds" => "5",
                 "end_seconds" => "17"
               },
               [],
               [],
               user
             )

    assert video.video_type_name == "in_action"
    assert video.description == nil
    assert video.ready == false
    assert video.source_type == :hosted
    assert video.thumbnail_url == "https://img.youtube.com/vi/dQw4w9WgXcQ/0.jpg"

    video_id = video.id

    staging =
      InActionStaging
      |> Ash.Query.filter(video_id == ^video_id)
      |> Ash.read_one!(actor: user)

    assert staging.source_video_id == "dQw4w9WgXcQ"
    assert staging.start_seconds == 5
    assert staging.end_seconds == 17

    assert_enqueued(
      worker: ProcessInActionVideo,
      queue: :video_processing,
      args: %{staging_id: staging.id}
    )
  end

  test "create_in_action_video rejects clips longer than fifteen seconds" do
    user = user_fixture()

    assert {:error, {:range, "inAction clips must be 15 seconds or shorter"}} =
             FosBjj.JiuJitsu.create_in_action_video(
               %{
                 url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                 title: "Too long",
                 attire: :gi,
                 start_seconds: 5,
                 end_seconds: 21
               },
               [],
               [],
               user
             )
  end
end
