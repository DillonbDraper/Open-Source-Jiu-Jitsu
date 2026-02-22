defmodule FosBjj.ConfigData do
  @moduledoc """
  Synchronizes static, code-defined config data into Ash-backed tables.
  """

  import Ecto.Query

  alias FosBjj.ConfigData.Schema

  def sync_all(opts \\ []) do
    list()
    |> required_first()
    |> List.flatten()
    |> Enum.each(&sync(&1, opts))

    :ok
  end

  def list do
    :fos_bjj
    |> Application.get_env(:ash_domains, [])
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.filter(&config_resource?/1)
  end

  def sync(resource, _opts \\ []) do
    config_values = Enum.map(resource.config_values(), &Schema.normalize_value/1)
    key_fields = resource.config_key_fields()

    validate_config_values!(resource, key_fields, config_values)

    repo = AshPostgres.DataLayer.Info.repo(resource)
    table = AshPostgres.DataLayer.Info.table(resource)

    resource_fields = resource_fields(resource)
    id_field = if :id in resource_fields, do: :id

    data_fields =
      config_values
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()
      |> Enum.filter(&(&1 in resource_fields))

    select_fields = Enum.uniq(((id_field && [id_field]) || []) ++ key_fields ++ data_fields)

    repo.transaction(fn ->
      existing_rows = repo.all(from(row in table, select: map(row, ^select_fields)))
      existing_by_key = Enum.group_by(existing_rows, &key_for(&1, key_fields))

      desired_by_key =
        config_values
        |> Map.new(fn value ->
          key = key_for(value, key_fields)
          {key, Map.take(value, data_fields)}
        end)

      existing_by_key
      |> Map.keys()
      |> Enum.reject(&Map.has_key?(desired_by_key, &1))
      |> Enum.each(fn key ->
        delete_by_key(repo, table, key_fields, key)
      end)

      Enum.each(desired_by_key, fn {key, desired_row} ->
        case Map.get(existing_by_key, key, []) do
          [] ->
            repo.insert_all(table, [desired_row])

          rows ->
            {keep_row, duplicate_rows} = pick_keep_and_duplicates(rows, id_field)
            delete_duplicate_rows(repo, table, duplicate_rows, id_field)
            update_by_key(repo, table, key_fields, key, keep_row, desired_row)
        end
      end)
    end)

    :ok
  end

  defp config_resource?(resource) do
    function_exported?(resource, :config_values, 0) and
      function_exported?(resource, :config_key_fields, 0)
  end

  defp required_first(remaining, required \\ [])

  defp required_first([], required), do: required

  defp required_first(remaining, required) do
    {deeper, ok} = Enum.split_with(remaining, &(&1 in dependent_resources(remaining)))
    required_first(deeper, [ok | required])
  end

  defp dependent_resources(remaining) do
    Enum.flat_map(remaining, fn resource ->
      resource
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(&match?(%Ash.Resource.Relationships.BelongsTo{}, &1))
      |> Enum.map(& &1.destination)
    end)
  end

  defp validate_config_values!(resource, key_fields, config_values) do
    if key_fields == [] do
      raise "#{inspect(resource)} must define at least one config key field"
    end

    Enum.each(config_values, fn value ->
      Enum.each(key_fields, fn key_field ->
        if not Map.has_key?(value, key_field) do
          raise "#{inspect(resource)} config row is missing key field #{inspect(key_field)}: #{inspect(value)}"
        end
      end)
    end)

    duplicates =
      config_values
      |> Enum.group_by(&key_for(&1, key_fields))
      |> Enum.filter(fn {_key, rows} -> length(rows) > 1 end)

    if duplicates != [] do
      duplicate_keys = Enum.map(duplicates, &elem(&1, 0))

      raise "#{inspect(resource)} config rows contain duplicate keys: #{inspect(duplicate_keys)}"
    end
  end

  defp resource_fields(resource) do
    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.map(& &1.name)
  end

  defp key_for(row, key_fields), do: Enum.map(key_fields, &Map.fetch!(row, &1))

  defp delete_by_key(repo, table, key_fields, key) do
    repo.delete_all(from(row in table, where: ^key_filter(key_fields, key)))
  end

  defp pick_keep_and_duplicates(rows, nil), do: {hd(rows), tl(rows)}

  defp pick_keep_and_duplicates(rows, id_field) do
    sorted = Enum.sort_by(rows, &Map.get(&1, id_field, 0))
    {hd(sorted), tl(sorted)}
  end

  defp delete_duplicate_rows(_repo, _table, [], _id_field), do: :ok

  defp delete_duplicate_rows(repo, table, duplicate_rows, id_field) when is_atom(id_field) do
    ids = Enum.map(duplicate_rows, &Map.get(&1, id_field))
    repo.delete_all(from(row in table, where: field(row, ^id_field) in ^ids))
  end

  defp delete_duplicate_rows(repo, table, duplicate_rows, nil) do
    Enum.each(duplicate_rows, fn row ->
      key_fields = Map.keys(row)
      key = Enum.map(key_fields, &Map.fetch!(row, &1))
      repo.delete_all(from(db_row in table, where: ^key_filter(key_fields, key)))
    end)
  end

  defp update_by_key(repo, table, key_fields, key, current_row, desired_row) do
    current = Map.take(current_row, Map.keys(desired_row))

    if current != desired_row do
      changes =
        desired_row
        |> Enum.reject(fn {field, _value} -> field in key_fields end)

      if changes != [] do
        repo.update_all(from(row in table, where: ^key_filter(key_fields, key)), set: changes)
      end
    end
  end

  defp key_filter(key_fields, key_values) do
    Enum.zip(key_fields, key_values)
    |> Enum.reduce(dynamic(true), fn {field_name, value}, dynamic_expr ->
      dynamic([row], ^dynamic_expr and field(row, ^field_name) == ^value)
    end)
  end
end
