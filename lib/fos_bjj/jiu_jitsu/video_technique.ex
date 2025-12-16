defmodule FosBjj.JiuJitsu.VideoTechnique do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("video_techniques")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
  end

  attributes do
    integer_primary_key(:id)

    attribute :video_id, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :technique_id, :integer do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :video, FosBjj.JiuJitsu.Video do
      source_attribute(:video_id)
      destination_attribute(:id)
      attribute_type(:integer)
      primary_key?(true)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :techniques, FosBjj.JiuJitsu.Technique do
      source_attribute(:technique_id)
      destination_attribute(:id)
      attribute_type(:integer)
      primary_key?(true)
      allow_nil?(false)
      public?(true)
    end
  end
end
