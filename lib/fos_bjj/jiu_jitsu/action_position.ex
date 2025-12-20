defmodule FosBjj.JiuJitsu.ActionPosition do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("action_positions")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
  end

  attributes do
    integer_primary_key(:id)

    attribute :action_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :position_name, :string do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :action, FosBjj.JiuJitsu.Action do
      source_attribute(:action_name)
      destination_attribute(:name)
      attribute_type(:string)
      primary_key?(true)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :position, FosBjj.JiuJitsu.Position do
      source_attribute(:position_name)
      destination_attribute(:name)
      attribute_type(:string)
      primary_key?(true)
      allow_nil?(false)
      public?(true)
    end
  end
end
