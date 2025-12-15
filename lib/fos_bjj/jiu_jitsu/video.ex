defmodule FosBjj.JiuJitsu.Video do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("videos")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:destroy])

    read :read do
      primary? true
      pagination offset?: true, countable: true
    end

    create :create do
      accept([:video_id, :description, :attire, :technique_id, :thumbnail_url])
      argument(:url, :string)
      change({FosBjj.CustomChanges.ProcessURL, url: :url})
      change(relate_actor(:created_by))
      change(relate_actor(:updated_by))
    end

    update :update do
      accept([
        :video_id,
        :description,
        :attire,
        :technique_id,
        :thumbnail_url
      ])

      change(relate_actor(:updated_by))
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :video_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :thumbnail_url, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :description, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :attire, :atom do
      constraints(one_of: [:gi, :no_gi])
      allow_nil?(false)
      public?(true)
    end

    attribute :technique_id, :integer do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :technique, FosBjj.JiuJitsu.Technique do
      source_attribute(:technique_id)
      destination_attribute(:id)
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end

    # Many-to-many to Grip through join table
    many_to_many :grips, FosBjj.JiuJitsu.Grip do
      through(FosBjj.JiuJitsu.VideoGrip)
      source_attribute(:id)
      source_attribute_on_join_resource(:video_id)
      destination_attribute(:name)
      destination_attribute_on_join_resource(:grip_name)
      public?(true)
    end

    # User tracking
    belongs_to :created_by, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(true)
      public?(true)
    end

    belongs_to :updated_by, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(true)
      public?(true)
    end
  end
end
