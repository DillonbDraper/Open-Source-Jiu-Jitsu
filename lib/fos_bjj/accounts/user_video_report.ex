defmodule FosBjj.Accounts.UserVideoReport do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("user_video_reports")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :submit do
      accept([:reason_name, :message, :video_id])
      change(relate_actor(:user))
    end

    update :resolve do
      accept([:admin_resolution_reason, :resolution_outcome])
      change(set_attribute(:resolved, true))
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :reason_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :message, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :resolved, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :admin_resolution_reason, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :resolution_outcome, :atom do
      allow_nil?(true)
      constraints(one_of: [:kept, :deleted])
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :reason, FosBjj.Accounts.VideoReportReason do
      source_attribute(:reason_name)
      destination_attribute(:name)
      attribute_type(:string)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :user, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :video, FosBjj.JiuJitsu.Video do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end
  end
end
