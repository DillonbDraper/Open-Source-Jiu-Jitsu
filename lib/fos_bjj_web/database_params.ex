defmodule FosBjjWeb.DatabaseParams do
  @moduledoc """
  Helpers for preserving database filter state in URLs.
  """

  @default_video_type "instructional"

  def build(source, overrides \\ []) do
    clear? = Keyword.get(overrides, :clear?, false)
    include_default_attire? = Keyword.get(overrides, :include_default_attire?, false)
    include_page? = Keyword.get(overrides, :include_page?, false)

    technique_id =
      if clear? do
        nil
      else
        Keyword.get(overrides, :technique_id, value(source, :selected_technique_id))
      end

    title =
      if clear? do
        nil
      else
        Keyword.get(overrides, :title, value(source, :title_search))
      end

    attire =
      if clear? do
        "both"
      else
        Keyword.get(overrides, :attire, value(source, :selected_attire) || "both")
      end

    video_type =
      overrides
      |> Keyword.get(:selected_video_type, value(source, :selected_video_type))
      |> normalize_video_type()

    page = Keyword.get(overrides, :page, value(source, :current_page) || 1)

    params = []

    params = if present?(technique_id), do: params ++ [technique_id: technique_id], else: params
    params = if present?(title), do: params ++ [title: title], else: params

    params =
      if include_default_attire? or (present?(attire) and attire != "both"),
        do: params ++ [attire: attire],
        else: params

    params =
      if video_type != @default_video_type, do: params ++ [video_type: video_type], else: params

    if include_page? or page_number(page) != 1, do: params ++ [page: page], else: params
  end

  def normalize_video_type("analysis"), do: "analysis"
  def normalize_video_type("in_action"), do: "in_action"
  def normalize_video_type(_video_type), do: @default_video_type

  def technique_id_for_query(nil), do: nil
  def technique_id_for_query(""), do: nil
  def technique_id_for_query(technique_id) when is_integer(technique_id), do: technique_id

  def technique_id_for_query(technique_id) when is_binary(technique_id),
    do: String.to_integer(technique_id)

  def attire_filter_values("gi"), do: [:gi]
  def attire_filter_values("no_gi"), do: [:no_gi]
  def attire_filter_values(:gi), do: [:gi]
  def attire_filter_values(:no_gi), do: [:no_gi]
  def attire_filter_values(_attire), do: [:gi, :no_gi]

  defp value(source, key) when is_map(source) do
    Map.get(source, key) || Map.get(source, to_string(key))
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true

  defp page_number(page) when is_integer(page), do: page
  defp page_number(page) when is_binary(page), do: String.to_integer(page)
  defp page_number(_page), do: 1
end
