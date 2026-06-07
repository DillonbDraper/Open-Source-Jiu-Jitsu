defmodule FosBjj.Workers.ProcessInActionVideo.Storage do
  @moduledoc """
  Storage boundary for processed inAction videos.

  The processor writes a finished MP4 to disk, then delegates to the configured
  storage backend. Development defaults to local static files; production workers
  can use the R2 backend by setting `IN_ACTION_VIDEO_STORAGE=r2`.
  """

  alias FosBjj.Workers.ProcessInActionVideo.Storage.{Local, R2}

  @type storage_key :: String.t()
  @type public_url :: String.t()
  @type option :: {:content_type, String.t()} | {:cache_control, String.t()}

  @callback store(Path.t(), storage_key(), [option()]) ::
              {:ok, public_url(), storage_key()} | {:error, term()}

  @callback cleanup_after_store?() :: boolean()

  def store(path, storage_key, opts \\ []) do
    backend().store(path, storage_key, opts)
  end

  def cleanup_after_store? do
    backend = backend()

    function_exported?(backend, :cleanup_after_store?, 0) and backend.cleanup_after_store?()
  end

  def backend do
    case Application.get_env(:fos_bjj, :in_action_video_storage, :local) do
      :local -> Local
      "local" -> Local
      :r2 -> R2
      "r2" -> R2
      module when is_atom(module) -> module
    end
  end
end
