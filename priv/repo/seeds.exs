# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FosBjj.Repo.insert!(%FosBjj.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

require Ash.Query

# ==========================================
# STEP 1: Create Dev User First
# ==========================================
# This must happen before other seed data because many tables
# have created_by_id foreign key constraints

IO.puts("\n=== Creating dev user ===")

dev_email = "dev@localhost"

dev_user =
  case FosBjj.Accounts.User
       |> Ash.Query.filter(email == ^dev_email)
       |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      # Create dev user
      case FosBjj.Accounts.User
           |> Ash.Changeset.for_create(
             :register_with_password,
             %{
               email: dev_email,
               user_name: "System User",
               password: "devpassword123",
               password_confirmation: "devpassword123"
             },
             authorize?: false
           )
           |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())
           |> Ash.Changeset.force_change_attribute(:role_name, "admin")
           |> Ash.create(authorize?: false) do
        {:ok, user} ->
          IO.puts("✓ Dev user created: #{user.email}")
          user

        {:error, reason} ->
          IO.puts("✗ Failed to create dev user: #{inspect(reason)}")
          raise "Cannot proceed without dev user"
      end

    {:ok, user} ->
      IO.puts("✓ Dev user already exists: #{user.email}")
      user

    {:error, reason} ->
      IO.puts("✗ Failed to query for dev user: #{inspect(reason)}")
      raise "Cannot proceed without dev user"
  end

# ==========================================
# STEP 2: Seed Lookup Tables
# ==========================================

IO.puts("\n=== Seeding lookup tables ===")
FosBjj.ConfigData.sync_all(actor: dev_user)

# ==========================================
# STEP 3: Load Additional Data from SQL
# ==========================================
# Load techniques, videos, and other user-generated content from SQL files
if File.exists?("priv/repo/sql_data") and File.dir?("priv/repo/sql_data") do
  FosBjj.Repo.SqlLoader.load_all()
end

IO.puts("\n✓ Database seeding complete!\n")
