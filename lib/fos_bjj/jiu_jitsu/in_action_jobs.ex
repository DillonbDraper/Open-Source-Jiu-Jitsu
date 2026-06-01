defmodule FosBjj.JiuJitsu.InActionJobs do
  @moduledoc """
  Service boundary for the external inAction video processing worker.
  """

  alias FosBjj.JiuJitsu.{InActionStaging, Video}

  def enqueue_processing_job(%InActionStaging{id: staging_id}) do
    enqueue_processing_job(staging_id)
  end

  def enqueue_processing_job(staging_id) do
    %{staging_id: staging_id}
    |> FosBjj.Workers.ProcessInActionVideo.new()
    |> Oban.insert()
  end

  def start_job(staging_id) do
    FosBjj.Repo.transact(fn ->
      with {:ok, staging} <- fetch_staging(staging_id),
           {:ok, staging} <-
             staging
             |> Ash.Changeset.for_update(:worker_update, %{
               status: :processing,
               failed_at: nil,
               failure_reason: nil
             })
             |> update_in_transaction() do
        {:ok, staging}
      end
    end)
  end

  def complete_job(staging_id, attrs) do
    with {:ok, hosted_video_url} <- required_string(attrs, "hosted_video_url") do
      storage_key = optional_string(attrs, "storage_key")
      now = DateTime.utc_now()

      FosBjj.Repo.transact(fn ->
        with {:ok, staging} <- fetch_staging(staging_id),
             {:ok, _video} <- mark_video_ready(staging.video_id, hosted_video_url),
             {:ok, staging} <-
               staging
               |> Ash.Changeset.for_update(:worker_update, %{
                 status: :processed,
                 processed_at: now,
                 failed_at: nil,
                 failure_reason: nil,
                 storage_key: storage_key
               })
               |> update_in_transaction() do
          {:ok, Ash.load!(staging, :video)}
        end
      end)
    end
  end

  def fail_job(staging_id, attrs) do
    failure_reason = optional_string(attrs, "failure_reason") || "Worker reported failure"
    now = DateTime.utc_now()

    FosBjj.Repo.transact(fn ->
      with {:ok, staging} <- fetch_staging(staging_id),
           {:ok, staging} <-
             staging
             |> Ash.Changeset.for_update(:worker_update, %{
               status: :failed,
               failed_at: now,
               failure_reason: failure_reason
             })
             |> update_in_transaction() do
        {:ok, Ash.load!(staging, :video)}
      end
    end)
  end

  defp fetch_staging(staging_id) do
    case Ash.get(InActionStaging, staging_id) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, staging} -> {:ok, staging}
      {:error, error} -> {:error, error}
    end
  end

  defp mark_video_ready(video_id, hosted_video_url) do
    with {:ok, video} <- Ash.get(Video, video_id) do
      video
      |> Ash.Changeset.for_update(:mark_processed_hosted, %{
        ready: true,
        source_type: :hosted,
        hosted_video_url: hosted_video_url
      })
      |> update_in_transaction()
    end
  end

  defp update_in_transaction(changeset) do
    case Ash.update(changeset, return_notifications?: true) do
      {:ok, record, _notifications} -> {:ok, record}
      {:error, error} -> {:error, error}
    end
  end

  defp required_string(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> {:error, {:validation, "#{key} is required"}}
          value -> {:ok, value}
        end

      _ ->
        {:error, {:validation, "#{key} is required"}}
    end
  end

  defp optional_string(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          value -> value
        end

      _ ->
        nil
    end
  end
end
