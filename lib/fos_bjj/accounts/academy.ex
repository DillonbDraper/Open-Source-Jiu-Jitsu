defmodule FosBjj.Accounts.Academy do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("academies")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
  end

  attributes do
    integer_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    many_to_many :users, FosBjj.Accounts.User do
      through(FosBjj.Accounts.AcademyUser)
      source_attribute(:id)
      source_attribute_on_join_resource(:academy_id)
      destination_attribute(:id)
      destination_attribute_on_join_resource(:user_id)
      public?(true)
    end
  end
end
