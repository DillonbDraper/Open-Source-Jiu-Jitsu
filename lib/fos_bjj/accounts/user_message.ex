defmodule FosBjj.Accounts.UserMessage do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("user_messages")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :send do
      accept([:body, :recipient_id])
      change(relate_actor(:sender))
    end

    create :send_system_message do
      accept([:body, :recipient_id])
    end

    update :mark_as_read do
      change(set_attribute(:received, true))
    end

    read :list_for_user do
      argument(:user_id, :integer, allow_nil?: false)

      pagination(offset?: true, countable: true)

      filter(expr(recipient_id == ^arg(:user_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, received: :asc, inserted_at: :desc)
      end)
    end

    read :unread_count do
      argument(:user_id, :integer, allow_nil?: false)
      filter(expr(recipient_id == ^arg(:user_id) and received == false))
    end

    read :inbox_messages do
      argument(:user_id, :integer, allow_nil?: false)

      filter(expr(recipient_id == ^arg(:user_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(received: :asc, inserted_at: :desc)
        |> Ash.Query.limit(5)
      end)
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :received, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :sender, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(true)
      public?(true)
    end

    belongs_to :recipient, FosBjj.Accounts.User do
      attribute_type(:integer)
      allow_nil?(false)
      public?(true)
    end
  end
end
