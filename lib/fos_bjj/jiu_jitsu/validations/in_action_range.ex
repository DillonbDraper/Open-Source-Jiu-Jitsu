defmodule FosBjj.JiuJitsu.Validations.InActionRange do
  @moduledoc """
  Validates that an inAction clip range is ordered and no longer than 15 seconds.
  """
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @max_duration_seconds 15

  @impl true
  def validate(changeset, _opts, _context) do
    start_seconds = Ash.Changeset.get_attribute(changeset, :start_seconds)
    end_seconds = Ash.Changeset.get_attribute(changeset, :end_seconds)

    cond do
      not is_integer(start_seconds) or not is_integer(end_seconds) ->
        :ok

      end_seconds <= start_seconds ->
        invalid(:end_seconds, end_seconds, "must be greater than start seconds")

      end_seconds - start_seconds > @max_duration_seconds ->
        invalid(:end_seconds, end_seconds, "inAction clips must be 15 seconds or shorter")

      true ->
        :ok
    end
  end

  defp invalid(field, value, message) do
    {:error, InvalidAttribute.exception(field: field, value: value, message: message)}
  end
end
