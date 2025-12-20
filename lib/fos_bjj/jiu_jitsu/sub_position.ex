defmodule FosBjj.JiuJitsu.SubPosition do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("sub_positions")
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

    attribute :position_name, :string do
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :position, FosBjj.JiuJitsu.Position do
      source_attribute(:position_name)
      destination_attribute(:name)
      public?(true)
    end

    has_many :techniques, FosBjj.JiuJitsu.Technique do
      source_attribute(:name)
      destination_attribute(:sub_position_name)
      public?(true)
    end
  end
end
