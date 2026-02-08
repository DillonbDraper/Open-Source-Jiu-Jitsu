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

    attribute :address_line_1, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :address_line_2, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :city, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :state, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :zip, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :country, :string do
      allow_nil?(true)
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
