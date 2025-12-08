defmodule FosBjj.JiuJitsu.TechniqueSubPosition do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "technique_sub_positions"
    repo FosBjj.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    integer_primary_key :id

    attribute :technique_id, :integer do
      allow_nil? false
      public? true
    end

    attribute :sub_position_name, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :technique, FosBjj.JiuJitsu.Technique do
      source_attribute :technique_id
      destination_attribute :id
      attribute_type :integer
      primary_key? true
      allow_nil? false
      public? true
    end

    belongs_to :sub_position, FosBjj.JiuJitsu.SubPosition do
      source_attribute :sub_position_name
      destination_attribute :name
      attribute_type :string
      primary_key? true
      allow_nil? false
      public? true
    end
  end
end
