defmodule FosBjj.ConfigData.Schema do
  @moduledoc """
  Behavior and helpers for Ash resources that define static, dev-managed
  configuration data.
  """

  @callback config_values() :: [map()]
  @callback config_key_fields() :: [atom()]

  defmacro __using__(opts \\ []) do
    key_fields = Keyword.get(opts, :key_fields)

    quote do
      @behaviour FosBjj.ConfigData.Schema

      @config_data_key_fields unquote(key_fields)

      def config_key_fields do
        @config_data_key_fields || Ash.Resource.Info.primary_key(__MODULE__)
      end

      defoverridable config_key_fields: 0
    end
  end

  def normalize_value(value) when is_map(value), do: value
  def normalize_value(value) when is_list(value), do: Map.new(value)
end
