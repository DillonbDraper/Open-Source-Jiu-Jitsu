defmodule FosBjj.Accounts.ContributorApplication do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("contributor_applications")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :submit do
      accept([:body])
      change(relate_actor(:user))
    end

    update :set_status do
      accept([:status])
      change(relate_actor(:updated_by))
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      constraints(one_of: [:pending, :approved, :denied])
      default(:pending)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, FosBjj.Accounts.User do
      attribute_type(:integer)
      public?(true)
    end

    belongs_to :updated_by, FosBjj.Accounts.User do
      attribute_type(:integer)
      public?(true)
    end
  end
end
