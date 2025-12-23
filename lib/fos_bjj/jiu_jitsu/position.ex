defmodule FosBjj.JiuJitsu.Position do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("positions")
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

  aggregates do
    count(:video_count, [:sub_positions, :techniques, :videos])
  end

  relationships do
    has_many :sub_positions, FosBjj.JiuJitsu.SubPosition do
      source_attribute(:name)
      destination_attribute(:position_name)
      public?(true)
    end

    many_to_many :orientations, FosBjj.JiuJitsu.Orientation do
      through(FosBjj.JiuJitsu.PositionOrientation)
      source_attribute(:name)
      destination_attribute(:name)
      source_attribute_on_join_resource(:position_name)
      destination_attribute_on_join_resource(:orientation_name)
      public?(true)
    end

    many_to_many :actions, FosBjj.JiuJitsu.Action do
      through(FosBjj.JiuJitsu.ActionPosition)
      source_attribute(:name)
      destination_attribute(:name)
      source_attribute_on_join_resource(:position_name)
      destination_attribute_on_join_resource(:action_name)
      public?(true)
    end
  end
end
