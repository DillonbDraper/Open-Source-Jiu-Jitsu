defmodule FosBjj.Workers.ProcessInActionVideo.YtDlpProcessorTest do
  use FosBjj.DataCase, async: false

  import FosBjj.Fixtures

  alias FosBjj.ConfigData
  alias FosBjj.JiuJitsu.{InActionStaging, VideoType}
  alias FosBjj.Workers.ProcessInActionVideo.YtDlpProcessor

  defmodule FakeExyt do
    def download(url, opts) do
      send(self(), {:yt_dlp_download, url, opts})
      {"output", output_path} = List.keyfind(opts, "output", 0)
      {:ok, output_path}
    end
  end

  setup do
    :ok = ConfigData.sync(VideoType)

    previous_exyt_mock = Application.get_env(:exyt_dlp, :exyt_mock)
    previous_output_dir = Application.get_env(:fos_bjj, :in_action_video_output_dir)
    previous_public_path = Application.get_env(:fos_bjj, :in_action_video_public_path)

    output_dir = Path.join(System.tmp_dir!(), "fos-bjj-in-action-test-#{System.unique_integer()}")

    Application.put_env(:exyt_dlp, :exyt_mock, FakeExyt)
    Application.put_env(:fos_bjj, :in_action_video_output_dir, output_dir)
    Application.put_env(:fos_bjj, :in_action_video_public_path, "/videos/in-action")

    on_exit(fn ->
      restore_env(:exyt_dlp, :exyt_mock, previous_exyt_mock)
      restore_env(:fos_bjj, :in_action_video_output_dir, previous_output_dir)
      restore_env(:fos_bjj, :in_action_video_public_path, previous_public_path)
      File.rm_rf(output_dir)
    end)

    :ok
  end

  test "process downloads the staged section as 720p mp4 and returns local URL metadata" do
    staging = staging_fixture(%{start_seconds: 10, end_seconds: 25})

    assert {:ok, public_url, storage_key} = YtDlpProcessor.process(staging)

    assert public_url == "/videos/in-action/in-action-#{staging.id}.mp4"
    assert storage_key == "in-action/in-action-#{staging.id}.mp4"

    assert_received {:yt_dlp_download, "https://www.youtube.com/watch?v=abc123", opts}
    assert {"download-sections", "*00:00:10-00:00:25"} in opts
    assert {"merge-output-format", "mp4"} in opts
    assert {"output", output_path} = List.keyfind(opts, "output", 0)
    assert Path.basename(output_path) == "in-action-#{staging.id}.mp4"

    assert {"format", format} = List.keyfind(opts, "format", 0)
    assert format =~ "height<=720"
    assert format =~ "ext=mp4"
  end

  test "download_section formats longer ranges for yt-dlp" do
    assert YtDlpProcessor.download_section(%{start_seconds: 3661, end_seconds: 3676}) ==
             "*01:01:01-01:01:16"
  end

  defp staging_fixture(attrs) do
    user = user_fixture()
    video = video_fixture(%{user: user, video_type_name: "in_action", ready: false})

    defaults = %{
      video_id: video.id,
      source_url: "https://www.youtube.com/watch?v=abc123",
      source_video_id: "abc123",
      start_seconds: 0,
      end_seconds: 15
    }

    Ash.create!(InActionStaging, Map.merge(defaults, attrs), action: :create, actor: user)
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
