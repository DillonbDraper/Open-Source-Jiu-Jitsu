defmodule FosBjj.Accounts.UserMessage do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("user_messages")
    repo(FosBjj.Repo)
  end

  policies do
    # Admins bypass all checks
    bypass actor_attribute_equals(:role_name, "admin") do
      authorize_if(always())
    end

    # System messages (no actor) are always allowed for create
    bypass action(:send_system_message) do
      authorize_if(always())
    end

    # Coaches and contributors can send messages
    policy action(:send) do
      authorize_if(actor_attribute_equals(:role_name, "coach"))
      authorize_if(actor_attribute_equals(:role_name, "contributor"))
    end

    # Recipients and senders can read, mark_as_read, and destroy their own messages
    policy action_type([:read, :update, :destroy]) do
      authorize_if(expr(recipient_id == ^actor(:id)))
      authorize_if(expr(sender_id == ^actor(:id)))
    end
  end

  actions do
    defaults([:read, :destroy])

    create :send do
      accept([:body, :recipient_id, :shared_video_id, :message_group_id])
      change(relate_actor(:sender))
      change(set_attribute(:type, :video_shared_by_coach))
    end

    create :send_system_message do
      accept([:body, :recipient_id])
      change(set_attribute(:type, :system_notification))
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

    read :sent_message_groups do
      argument(:sender_id, :integer, allow_nil?: false)

      filter(expr(sender_id == ^arg(:sender_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.distinct(:message_group_id)
        |> Ash.Query.distinct_sort(inserted_at: :desc)
        |> Ash.Query.sort(inserted_at: :desc)
      end)

      pagination(offset?: true, countable: true)
    end

    read :group_recipients do
      argument(:message_group_ids, {:array, :uuid}, allow_nil?: false)
      argument(:sender_id, :integer, allow_nil?: false)

      filter(expr(sender_id == ^arg(:sender_id) and message_group_id in ^arg(:message_group_ids)))
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :body, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :received, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :type, :atom do
      allow_nil?(false)
      constraints(one_of: [:system_notification, :video_shared_by_coach])
      default(:system_notification)
      public?(true)
    end

    attribute :message_group_id, :uuid do
      allow_nil?(false)
      default(&Ecto.UUID.generate/0)
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

    belongs_to :shared_video, FosBjj.JiuJitsu.Video do
      attribute_type(:integer)
      allow_nil?(true)
      public?(true)
    end
  end

  def type_label(type) do
    case type do
      :system_notification -> "System Notification"
      "system_notification" -> "System Notification"
      :video_shared_by_coach -> "Video Shared by Coach"
      "video_shared_by_coach" -> "Video Shared by Coach"
      _ -> "Message"
    end
  end

  def type_value(type) do
    case type do
      :system_notification -> :system_notification
      "system_notification" -> :system_notification
      :video_shared_by_coach -> :video_shared_by_coach
      "video_shared_by_coach" -> :video_shared_by_coach
      _ -> nil
    end
  end
end
