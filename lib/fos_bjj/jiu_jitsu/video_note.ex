defmodule FosBjj.JiuJitsu.VideoNote do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("video_notes")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
    end

    create :create do
      accept([:video_id, :body, :video_timestamp])
      change(relate_actor(:user))
    end

    update :update do
      require_atomic?(false)

      accept([
        :body,
        :video_timestamp
      ])

      change(relate_actor(:user))
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :video_timestamp, :integer do
      allow_nil?(true)
      public?(true)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, FosBjj.Accounts.User do
      attribute_type(:integer)
      public?(true)
    end

    belongs_to :video, FosBjj.JiuJitsu.Video do
      attribute_type(:integer)
      public?(true)
    end
  end
end
