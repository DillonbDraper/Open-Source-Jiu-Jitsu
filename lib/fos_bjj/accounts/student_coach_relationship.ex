defmodule FosBjj.Accounts.StudentCoachRelationship do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("student_coach_relationships")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :follow do
      accept([:coach_id])
      change(relate_actor(:learner))
    end
  end

  attributes do
    integer_primary_key(:id)

    timestamps()
  end

  relationships do
    belongs_to :learner, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :coach, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_learner_coach, [:learner_id, :coach_id])
  end
end
