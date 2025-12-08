defmodule FosBjj.JiuJitsu.Technique do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "techniques"
    repo FosBjj.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :orientation_name, :string do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    # Many-to-many to Position through join table
    many_to_many :positions, FosBjj.JiuJitsu.Position do
      through FosBjj.JiuJitsu.TechniquePosition
      source_attribute :id
      source_attribute_on_join_resource :technique_id
      destination_attribute :name
      destination_attribute_on_join_resource :position_name
      public? true
    end

    # Many-to-many to SubPosition through join table
    many_to_many :sub_positions, FosBjj.JiuJitsu.SubPosition do
      through FosBjj.JiuJitsu.TechniqueSubPosition
      source_attribute :id
      source_attribute_on_join_resource :technique_id
      destination_attribute :name
      destination_attribute_on_join_resource :sub_position_name
      public? true
    end

    # Many-to-many to Grip through join table
    many_to_many :grips, FosBjj.JiuJitsu.Grip do
      through FosBjj.JiuJitsu.TechniqueGrip
      source_attribute :id
      source_attribute_on_join_resource :technique_id
      destination_attribute :name
      destination_attribute_on_join_resource :grip_name
      public? true
    end

    belongs_to :orientation, FosBjj.JiuJitsu.Orientation do
      source_attribute :orientation_name
      destination_attribute :name
      attribute_type :string
      public? true
    end
  end
end
