defmodule FosBjj.JiuJitsu.InActionVideos do
  @moduledoc """
  Context functions for staging and processing inAction videos.
  """

  alias FosBjj.JiuJitsu.{InActionJobs, InActionStaging, Video}

  @max_duration_seconds 15

  def create_in_action_video(params, selected_grips, selected_techniques, current_user) do
    with {:ok, source_video_id} <- source_video_id_from_url(param(params, :url)),
         {:ok, start_seconds} <- parse_seconds(param(params, :start_seconds), "Start time"),
         {:ok, end_seconds} <- parse_seconds(param(params, :end_seconds), "End time"),
         :ok <- validate_in_action_range(start_seconds, end_seconds) do
      selected_grips = List.wrap(selected_grips)
      selected_techniques = List.wrap(selected_techniques)

      video_params = %{
        video_id: Ecto.UUID.generate(),
        title: param(params, :title),
        description: nil,
        attire: param(params, :attire),
        thumbnail_url: "https://img.youtube.com/vi/#{source_video_id}/0.jpg",
        video_type_name: "in_action",
        ready: false,
        source_type: :hosted
      }

      FosBjj.Repo.transact(fn ->
        video_changeset =
          Video
          |> Ash.Changeset.for_create(:create, video_params, actor: current_user)
          |> Ash.Changeset.manage_relationship(:grips, selected_grips, type: :append_and_remove)
          |> Ash.Changeset.manage_relationship(:techniques, selected_techniques,
            type: :append_and_remove
          )

        with {:ok, video, _notifications} <-
               Ash.create(video_changeset, return_notifications?: true),
             staging_changeset =
               Ash.Changeset.for_create(
                 InActionStaging,
                 :create,
                 %{
                   video_id: video.id,
                   source_url: param(params, :url),
                   source_video_id: source_video_id,
                   start_seconds: start_seconds,
                   end_seconds: end_seconds
                 },
                 actor: current_user
               ),
             {:ok, staging, _notifications} <-
               Ash.create(staging_changeset, return_notifications?: true),
             {:ok, _job} <- InActionJobs.enqueue_processing_job(staging) do
          {:ok, video}
        end
      end)
    end
  end

  defp param(params, key) when is_map(params) do
    Map.get(params, key) || Map.get(params, to_string(key))
  end

  defp source_video_id_from_url(url) when is_binary(url) do
    case VideoLinkHelper.extract_id(url) do
      {_source, video_id} when is_binary(video_id) and video_id != "" -> {:ok, video_id}
      _ -> {:error, "Enter a valid YouTube URL for the inAction source video"}
    end
  rescue
    _error -> {:error, "Enter a valid YouTube URL for the inAction source video"}
  end

  defp source_video_id_from_url(_url),
    do: {:error, "Enter a valid YouTube URL for the inAction source video"}

  defp parse_seconds(value, _label) when is_integer(value), do: {:ok, value}

  defp parse_seconds(value, label) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, ""} -> {:ok, seconds}
      _ -> {:error, {:range, "#{label} must be a whole number of seconds"}}
    end
  end

  defp parse_seconds(_value, label),
    do: {:error, {:range, "#{label} must be a whole number of seconds"}}

  defp validate_in_action_range(start_seconds, end_seconds)
       when start_seconds < 0 or end_seconds < 0,
       do: {:error, {:range, "inAction start and end times must be zero or greater"}}

  defp validate_in_action_range(start_seconds, end_seconds) when end_seconds <= start_seconds,
    do: {:error, {:range, "inAction end time must be after the start time"}}

  defp validate_in_action_range(start_seconds, end_seconds)
       when end_seconds - start_seconds > @max_duration_seconds,
       do: {:error, {:range, "inAction clips must be 15 seconds or shorter"}}

  defp validate_in_action_range(_start_seconds, _end_seconds), do: :ok
end
