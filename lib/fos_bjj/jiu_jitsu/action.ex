defmodule FosBjj.JiuJitsu.Action do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("actions")
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
    has_many :techniques, FosBjj.JiuJitsu.Technique do
      source_attribute(:name)
      destination_attribute(:action_name)
      public?(true)
    end

    has_many :action_position_orientations, FosBjj.JiuJitsu.ActionPositionOrientation do
      source_attribute(:name)
      destination_attribute(:action_name)
      public?(true)
    end
  end
end
