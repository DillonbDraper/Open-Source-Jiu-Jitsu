defmodule FosBjj.JiuJitsu.PositionOrientation do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("position_orientations")
    repo(FosBjj.Repo)
  end

  actions do
    read :read do
      primary?(true)
    end
  end

  attributes do
    attribute :position_name, :string do
      allow_nil?(false)
      primary_key?(true)
    end

    attribute :orientation_name, :string do
      allow_nil?(false)
      primary_key?(true)
    end
  end

  relationships do
    belongs_to :position, FosBjj.JiuJitsu.Position do
      source_attribute(:position_name)
      destination_attribute(:name)
    end

    belongs_to :orientation, FosBjj.JiuJitsu.Orientation do
      source_attribute(:orientation_name)
      destination_attribute(:name)
    end
  end

  @config_values [
    %{position_name: "standing", orientation_name: "offense"},
    %{position_name: "standing", orientation_name: "defense"},
    %{position_name: "guard", orientation_name: "top"},
    %{position_name: "guard", orientation_name: "bottom"},
    %{position_name: "mount", orientation_name: "top"},
    %{position_name: "mount", orientation_name: "bottom"},
    %{position_name: "side_control", orientation_name: "top"},
    %{position_name: "side_control", orientation_name: "bottom"},
    %{position_name: "turtle", orientation_name: "top"},
    %{position_name: "turtle", orientation_name: "bottom"},
    %{position_name: "back", orientation_name: "superior"},
    %{position_name: "back", orientation_name: "inferior"},
    %{position_name: "leg_entanglement", orientation_name: "superior"},
    %{position_name: "leg_entanglement", orientation_name: "inferior"}
  ]

  @impl true
  def config_values, do: @config_values
end
