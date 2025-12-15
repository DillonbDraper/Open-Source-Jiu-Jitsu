defmodule FosBjj.CustomChanges.ProcessURL do
  use Ash.Resource.Change
  # transform and validate opts
  @impl true
  def init(opts) do
    if is_atom(opts[:url]) do
      {:ok, opts}
    else
      {:error, "attribute must be an atom!"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, opts[:url]) do
      {:ok, url} when is_binary(url) ->
        {_source, video_id} = VideoLinkHelper.extract_id(url)
        thumbnail_url = "https://img.youtube.com/vi/#{video_id}/0.jpg"

        Ash.Changeset.force_change_attribute(changeset, :video_id, video_id)
        |> Ash.Changeset.change_attribute(:thumbnail_url, thumbnail_url)

      _ ->
        changeset
    end
  end
end
