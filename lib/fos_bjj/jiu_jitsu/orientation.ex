defmodule FosBjj.JiuJitsu.Orientation do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("orientations")
    repo(FosBjj.Repo)
  end

  actions do
    read :read do
      primary?(true)
    end
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
    end

    attribute :label, :string do
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    many_to_many :positions, FosBjj.JiuJitsu.Position do
      through(FosBjj.JiuJitsu.PositionOrientation)
      source_attribute(:name)
      destination_attribute(:name)
      source_attribute_on_join_resource(:orientation_name)
      destination_attribute_on_join_resource(:position_name)
      public?(true)
    end

    has_many :action_sub_position_orientations, FosBjj.JiuJitsu.ActionSubPositionOrientation do
      source_attribute(:name)
      destination_attribute(:orientation_name)
      public?(true)
    end
  end

  @config_values [
    %{name: "top", label: "Top"},
    %{name: "bottom", label: "Bottom"},
    %{name: "superior", label: "Superior"},
    %{name: "inferior", label: "Inferior"},
    %{name: "offense", label: "Offense"},
    %{name: "defense", label: "Defense"}
  ]

  @impl true
  def config_values, do: @config_values
end
