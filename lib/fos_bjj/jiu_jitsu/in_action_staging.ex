defmodule FosBjj.JiuJitsu.InActionStaging do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("in_action_staging")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:video_id, :source_url, :source_video_id, :start_seconds, :end_seconds, :status])
      change(relate_actor(:created_by))
      change(relate_actor(:updated_by))
    end

    update :update do
      require_atomic?(false)

      accept([
        :status,
        :start_seconds,
        :end_seconds,
        :processed_at,
        :failed_at,
        :failure_reason,
        :storage_key
      ])

      change(relate_actor(:updated_by))
    end

    update :worker_update do
      require_atomic?(false)

      accept([
        :status,
        :processed_at,
        :failed_at,
        :failure_reason,
        :storage_key
      ])
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :source_url, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :source_video_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :start_seconds, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :end_seconds, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :processing, :processed, :failed])
      allow_nil?(false)
      default(:pending)
      public?(true)
    end

    attribute :processed_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(true)
    end

    attribute :failed_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(true)
    end

    attribute :failure_reason, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :storage_key, :string do
      allow_nil?(true)
      public?(true)
    end

    timestamps()
  end

  validations do
    validate(compare(:start_seconds, greater_than_or_equal_to: 0))
    validate(compare(:end_seconds, greater_than: :start_seconds))
    validate({FosBjj.JiuJitsu.Validations.InActionRange, []})
  end

  identities do
    identity(:unique_video_id, [:video_id])
  end

  relationships do
    belongs_to :video, FosBjj.JiuJitsu.Video do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :created_by, FosBjj.Accounts.User do
      attribute_type(:integer)
      public?(true)
    end

    belongs_to :updated_by, FosBjj.Accounts.User do
      attribute_type(:integer)
      public?(true)
    end
  end
end
