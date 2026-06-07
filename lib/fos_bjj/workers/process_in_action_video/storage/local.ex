defmodule FosBjj.Workers.ProcessInActionVideo.Storage.Local do
  @moduledoc """
  Local filesystem storage for processed inAction videos.

  This preserves the existing development behavior: files are served by Phoenix
  from `priv/static/videos/in-action` and database rows store `/videos/in-action/...`.
  """

  @behaviour FosBjj.Workers.ProcessInActionVideo.Storage

  @impl true
  def store(path, storage_key, _opts \\ []) do
    filename = Path.basename(storage_key)
    output_dir = output_dir()
    final_path = Path.join(output_dir, filename)

    with :ok <- maybe_copy(path, final_path) do
      {:ok, public_url(filename), storage_key}
    end
  end

  @impl true
  def cleanup_after_store?, do: false

  defp maybe_copy(path, final_path) do
    if Path.expand(path) == Path.expand(final_path) do
      :ok
    else
      with :ok <- File.mkdir_p(Path.dirname(final_path)),
           :ok <- File.cp(path, final_path) do
        :ok
      end
    end
  end

  defp output_dir do
    Application.get_env(
      :fos_bjj,
      :in_action_video_output_dir,
      Path.expand("../../../../../priv/static/videos/in-action", __DIR__)
    )
  end

  defp public_url(filename) do
    public_path = Application.get_env(:fos_bjj, :in_action_video_public_path, "/videos/in-action")
    join_url_path(public_path, filename)
  end

  defp join_url_path(left, right) do
    left = String.trim_trailing(left, "/")
    right = String.trim_leading(right, "/")

    "#{left}/#{right}"
  end
end
