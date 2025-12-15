defmodule FosBjj.JiuJitsu.PositionOrientation do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "position_orientations"
    repo FosBjj.Repo
  end

  actions do
    read :read do
      primary? true
    end
  end

  attributes do
    attribute :position_name, :string do
      allow_nil? false
      primary_key? true
    end

    attribute :orientation_name, :string do
      allow_nil? false
      primary_key? true
    end
  end

  relationships do
    belongs_to :position, FosBjj.JiuJitsu.Position do
      source_attribute :position_name
      destination_attribute :name
    end

    belongs_to :orientation, FosBjj.JiuJitsu.Orientation do
      source_attribute :orientation_name
      destination_attribute :name
    end
  end
end
