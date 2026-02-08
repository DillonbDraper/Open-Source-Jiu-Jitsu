defmodule FosBjj.Accounts.AcademyUser do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("academy_users")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy, create: :*])

    update :set_primary do
      accept([:primary])
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :primary, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :academy, FosBjj.Accounts.Academy do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :user, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_user_academy, [:user_id, :academy_id])
  end
end
