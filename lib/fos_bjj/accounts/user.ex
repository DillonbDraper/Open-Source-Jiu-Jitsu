defmodule FosBjj.Accounts.User do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change?(true)
      end

      confirmation :confirm_new_user do
        monitor_fields([:email])
        confirm_on_create?(true)
        confirm_on_update?(false)
        require_interaction?(true)
        confirmed_at_field(:confirmed_at)
        auto_confirm_actions([:reset_password_with_token])
        sender(FosBjj.Accounts.User.Senders.SendNewUserConfirmationEmail)
      end
    end

    tokens do
      enabled?(true)
      token_resource(FosBjj.Accounts.Token)
      signing_secret(FosBjj.Secrets)
      store_all_tokens?(true)
      require_token_presence_for_authentication?(true)
    end

    strategies do
      password :password do
        identity_field(:email)
        hash_provider(AshAuthentication.BcryptProvider)

        resettable do
          sender(FosBjj.Accounts.User.Senders.SendPasswordResetEmail)
          # these configurations will be the default in a future release
          password_reset_action_name(:reset_password_with_token)
          request_password_reset_action_name(:request_password_reset_token)
        end
      end
    end
  end

  postgres do
    table("users")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read])

    read :get_by_subject do
      description("Get a user by the subject claim in a JWT")
      argument(:subject, :string, allow_nil?: false)
      get?(true)
      prepare(AshAuthentication.Preparations.FilterBySubject)
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic?(false)
      accept([])
      argument(:current_password, :string, sensitive?: true, allow_nil?: false)

      argument(:password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]
      )

      argument(:password_confirmation, :string, sensitive?: true, allow_nil?: false)

      validate(confirm(:password, :password_confirmation))

      validate(
        {AshAuthentication.Strategy.Password.PasswordValidation,
         strategy_name: :password, password_argument: :current_password}
      )

      change({AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password})
    end

    read :sign_in_with_password do
      description("Attempt to sign in using email or username and password.")
      get?(true)

      argument :email, :ci_string do
        description("The email or username to use for retrieving the user.")
        allow_nil?(false)
      end

      argument :password, :string do
        description("The password to check for the matching user.")
        allow_nil?(false)
        sensitive?(true)
      end

      # Filter by email OR user_name matching the provided identifier
      filter(expr(email == ^arg(:email) or user_name == ^arg(:email)))

      # validates the provided email and password and generates a token
      prepare(AshAuthentication.Strategy.Password.SignInPreparation)

      metadata :token, :string do
        description("A JWT that can be used to authenticate the user.")
        allow_nil?(false)
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description("Attempt to sign in using a short-lived sign in token.")
      get?(true)

      argument :token, :string do
        description("The short-lived sign in token.")
        allow_nil?(false)
        sensitive?(true)
      end

      # validates the provided sign in token and generates a token
      prepare(AshAuthentication.Strategy.Password.SignInWithTokenPreparation)

      metadata :token, :string do
        description("A JWT that can be used to authenticate the user.")
        allow_nil?(false)
      end
    end

    create :register_with_password do
      description("Register a new user with a username, email, and password.")

      argument :user_name, :string do
        allow_nil?(false)
      end

      argument :email, :ci_string do
        allow_nil?(false)
      end

      argument :password, :string do
        description("The proposed password for the user, in plain text.")
        allow_nil?(false)
        constraints(min_length: 8)
        sensitive?(true)
      end

      argument :password_confirmation, :string do
        description("The proposed password for the user (again), in plain text.")
        allow_nil?(false)
        sensitive?(true)
      end

      # Sets the user_name from the argument
      change(set_attribute(:user_name, arg(:user_name)))

      # Sets the email from the argument
      change(set_attribute(:email, arg(:email)))

      # Hashes the provided password
      change(AshAuthentication.Strategy.Password.HashPasswordChange)

      # Generates an authentication token for the user
      change(AshAuthentication.GenerateTokenChange)

      # validates that the password matches the confirmation
      validate(AshAuthentication.Strategy.Password.PasswordConfirmationValidation)

      metadata :token, :string do
        description("A JWT that can be used to authenticate the user.")
        allow_nil?(false)
      end
    end

    action :request_password_reset_token do
      description("Send password reset instructions to a user if they exist.")

      argument :email, :ci_string do
        allow_nil?(false)
      end

      # creates a reset token and invokes the relevant senders
      run({AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email})
    end

    read :get_by_email do
      description("Looks up a user by their email")
      argument(:email, :ci_string, allow_nil?: false)
      get_by(:email)
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil?(false)
        sensitive?(true)
      end

      argument :password, :string do
        description("The proposed password for the user, in plain text.")
        allow_nil?(false)
        constraints(min_length: 8)
        sensitive?(true)
      end

      argument :password_confirmation, :string do
        description("The proposed password for the user (again), in plain text.")
        allow_nil?(false)
        sensitive?(true)
      end

      # validates the provided reset token
      validate(AshAuthentication.Strategy.Password.ResetTokenValidation)

      # validates that the password matches the confirmation
      validate(AshAuthentication.Strategy.Password.PasswordConfirmationValidation)

      # Hashes the provided password
      change(AshAuthentication.Strategy.Password.HashPasswordChange)

      # Generates an authentication token for the user
      change(AshAuthentication.GenerateTokenChange)
    end

    create :sign_in_with_magic_link do
      description("Sign in or register a user with magic link.")

      argument :token, :string do
        description("The token from the magic link that was sent to the user")
        allow_nil?(false)
      end

      upsert?(true)
      upsert_identity(:unique_email)
      upsert_fields([:email])

      # Uses the information from the token to create or sign in the user
      change(AshAuthentication.Strategy.MagicLink.SignInChange)

      metadata :token, :string do
        allow_nil?(false)
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil?(false)
      end

      run(AshAuthentication.Strategy.MagicLink.Request)
    end

    update :update_role do
      accept([])
      argument(:role, :string, allow_nil?: false)
      change(set_attribute(:role_name, arg(:role)))
    end

    update :update_profile do
      require_atomic?(false)
      accept([:bjj_belt, :other_high_level_experience])
      argument(:academy_ids, {:array, :integer})

      argument(:role, :string,
        allow_nil?: false,
        constraints: [match: ~r/^(student|coach)$/]
      )

      change(set_attribute(:role_name, arg(:role)))
      change(manage_relationship(:academy_ids, :academies, type: :append_and_remove))
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    bypass actor_attribute_equals(:role_name, "admin") do
      authorize_if(always())
    end

    policy action_type(:read) do
      description(
        "Users can read their own record, coaches, and students when they are a coach or contributor"
      )

      authorize_if(expr(id == ^actor(:id)))

      authorize_if(
        expr(^actor(:role_name) in ["coach", "contributor"] and role_name == "student")
      )

      authorize_if(expr(role_name in ["coach", "contributor", "admin"]))
    end

    policy action_type(:update) do
      description("Users can update their own specific record")
      authorize_if(expr(id == ^actor(:id)))
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
    end

    attribute :user_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :hashed_password, :string do
      sensitive?(true)
    end

    attribute(:confirmed_at, :utc_datetime_usec)

    attribute :role_name, :string do
      allow_nil?(true)
      default("student")
      public?(true)
    end

    attribute :bjj_belt, :atom do
      allow_nil?(true)
      public?(true)
      constraints(one_of: [:white, :blue, :purple, :brown, :black])
    end

    attribute :other_high_level_experience, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :role, FosBjj.Accounts.Role do
      source_attribute(:role_name)
      destination_attribute(:name)
      attribute_type(:string)
      define_attribute?(false)
      public?(true)
    end

    # Coaches that this user follows (as a learner)
    many_to_many :followed_coaches, FosBjj.Accounts.User do
      through(FosBjj.Accounts.StudentCoachRelationship)
      source_attribute(:id)
      source_attribute_on_join_resource(:learner_id)
      destination_attribute(:id)
      destination_attribute_on_join_resource(:coach_id)
      public?(true)
    end

    # Students who follow this user (as a coach)
    many_to_many :followers, FosBjj.Accounts.User do
      through(FosBjj.Accounts.StudentCoachRelationship)
      source_attribute(:id)
      source_attribute_on_join_resource(:coach_id)
      destination_attribute(:id)
      destination_attribute_on_join_resource(:learner_id)
      public?(true)
    end

    many_to_many :academies, FosBjj.Accounts.Academy do
      through(FosBjj.Accounts.AcademyUser)
      source_attribute(:id)
      source_attribute_on_join_resource(:user_id)
      destination_attribute(:id)
      destination_attribute_on_join_resource(:academy_id)
      public?(true)
    end
  end

  identities do
    identity(:unique_email, [:email])
    identity(:unique_user_name, [:user_name])
  end

  @doc "Check if user has verified their email"
  def verified?(%{confirmed_at: confirmed_at}) when not is_nil(confirmed_at), do: true
  def verified?(_), do: false

  @doc "Check if user has admin role (requires verification)"
  def admin?(%{role_name: "admin"} = user), do: verified?(user)
  def admin?(_), do: false

  @doc "Check if user has coach role (requires verification)"
  def coach?(%{role_name: "coach"} = user), do: verified?(user)
  def coach?(_), do: false

  @doc "Check if user has contributor role (requires verification)"
  def contributor?(%{role_name: "contributor"} = user), do: verified?(user)
  def contributor?(_), do: false

  @doc "Check if user has coach, contributor, or admin role (requires verification)"
  def coach_or_admin?(%{role_name: role} = user) when role in ["coach", "contributor", "admin"],
    do: verified?(user)

  def coach_or_admin?(_), do: false

  @doc "Check if user has contributor or admin role (requires verification)"
  def contributor_or_admin?(%{role_name: role} = user) when role in ["contributor", "admin"],
    do: verified?(user)

  def contributor_or_admin?(_), do: false

  @doc "Eligibility for contributor application based on belt and other experience."
  def contributor_application_eligible?(%{
        bjj_belt: :black,
        other_high_level_experience: _other
      }),
      do: true

  def contributor_application_eligible?(%{bjj_belt: "black"}), do: true

  def contributor_application_eligible?(%{other_high_level_experience: true}), do: true
  def contributor_application_eligible?(_), do: false
end
