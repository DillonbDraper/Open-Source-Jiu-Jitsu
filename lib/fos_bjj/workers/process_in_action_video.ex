defmodule FosBjj.Workers.ProcessInActionVideo do
  @moduledoc """
  Oban worker entrypoint for processing staged inAction videos.

  The actual download/FFmpeg/upload implementation is intentionally delegated to a
  configurable processor module so the production web node can enqueue jobs while a
  separate worker node, connected to Postgres over the private network, performs the
  CPU-heavy work.
  """

  use Oban.Worker,
    queue: :video_processing,
    max_attempts: 5,
    unique: [fields: [:args], keys: [:staging_id], period: :infinity]

  alias FosBjj.JiuJitsu.InActionJobs

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"staging_id" => staging_id}}) do
    with {:ok, staging} <- InActionJobs.start_job(staging_id),
         {:ok, hosted_video_url, storage_key} <- processor().process(staging),
         {:ok, _staging} <-
           InActionJobs.complete_job(staging.id, %{
             "hosted_video_url" => hosted_video_url,
             "storage_key" => storage_key
           }) do
      :ok
    else
      {:error, reason} = error ->
        _ = InActionJobs.fail_job(staging_id, %{"failure_reason" => inspect(reason)})
        error
    end
  end

  def perform(%Oban.Job{}), do: {:discard, :missing_staging_id}

  defp processor do
    Application.get_env(
      :fos_bjj,
      :in_action_video_processor,
      FosBjj.Workers.ProcessInActionVideo.YtDlpProcessor
    )
  end
end
