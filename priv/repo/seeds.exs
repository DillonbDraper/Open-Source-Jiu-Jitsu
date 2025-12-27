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

alias FosBjj.JiuJitsu.{
  Grip,
  Position,
  SubPosition,
  Orientation,
  PositionOrientation,
  Action,
  ActionPositionOrientation
}

# Grips
grips = [
  %{name: "two_on_one", label: "2 On 1"},
  %{name: "tricep_tie", label: "Tricep Tie(s)"},
  %{name: "scoop_grip", label: "Scoop Grip"},
  %{name: "double_sleeve", label: "Double Sleeve/Wrist"},
  %{name: "double_collar", label: "Double Collar"},
  %{name: "collar_sleeve", label: "Collar & Sleeve"},
  %{name: "belt_grip", label: "Belt Grip"},
  %{name: "over_under", label: "Over/Under"},
  %{name: "cross_grip", label: "Cross Grip"},
  %{name: "over_hook", label: "Over Hook"},
  %{name: "under_hook", label: "Under Hook"},
  %{name: "one_on_one", label: "1 On 1"},
  %{name: "collar_elbow", label: "Collar & Elbow"},
  %{name: "cross_collar", label: "Cross Collar"},
  %{name: "ankle_grip", label: "Ankle Grip"},
  %{name: "ankle_lock_grip", label: "Ankle Lock Grip"}
]

for grip <- grips do
  Ash.Seed.seed!(Grip, grip, actor: dev_user)
end

# Positions
positions = [
  %{name: "standing", label: "Standing"},
  %{name: "guard", label: "Guard"},
  %{name: "mount", label: "Mount"},
  %{name: "side_control", label: "Side Control"},
  %{name: "back", label: "Back"},
  %{name: "leg_entanglement", label: "Leg Entanglement"},
  %{name: "turtle", label: "Turtle"}
]

for position <- positions do
  Ash.Seed.seed!(Position, position, actor: dev_user)
end

# Orientations
orientations = [
  %{name: "top", label: "Top"},
  %{name: "bottom", label: "Bottom"},
  %{name: "superior", label: "Superior"},
  %{name: "inferior", label: "Inferior"},
  %{name: "offense", label: "Offense"},
  %{name: "defense", label: "Defense"}
]

for orientation <- orientations do
  Ash.Seed.seed!(Orientation, orientation, actor: dev_user)
end

# Position Orientations
position_orientations = [
  # Standing
  {"standing", "offense"},
  {"standing", "defense"},
  # Guard, Mount, Side Control, Turtle -> Top, Bottom
  {"guard", "top"},
  {"guard", "bottom"},
  {"mount", "top"},
  {"mount", "bottom"},
  {"side_control", "top"},
  {"side_control", "bottom"},
  {"turtle", "top"},
  {"turtle", "bottom"},
  # Back, Leg Entanglement -> Superior, Inferior
  {"back", "superior"},
  {"back", "inferior"},
  {"leg_entanglement", "superior"},
  {"leg_entanglement", "inferior"}
]

for {pos, ori} <- position_orientations do
  Ash.Seed.seed!(PositionOrientation, %{position_name: pos, orientation_name: ori}, actor: dev_user)
end

# SubPositions
sub_positions = [
  # Standing "subpositions"
  %{name: "upper_body", label: "Upper Body", position_name: "standing"},
  %{name: "leg_grab", label: "Leg Grab", position_name: "standing"},
  %{name: "ashi_waza", label: "Ashi Waza", position_name: "standing"},
  %{name: "sacrifice_sutemi_waza", label: "Sacrifice (Sutemi Waza)", position_name: "standing"},

  # Guard subpositions
  %{name: "closed_guard", label: "Closed Guard", position_name: "guard"},
  %{name: "open_guard", label: "Open Guard", position_name: "guard"},
  %{name: "half_guard", label: "Half Guard", position_name: "guard"},
  %{name: "butterfly_guard", label: "Butterfly Guard", position_name: "guard"},
  %{name: "de_la_riva_guard", label: "De La Riva Guard", position_name: "guard"},
  %{name: "reverse_de_la_riva_guard", label: "Reverse De La Riva Guard", position_name: "guard"},
  %{name: "single_leg_x_guard", label: "Single Leg X Guard", position_name: "guard"},
  %{name: "x_guard", label: "X Guard", position_name: "guard"},
  %{name: "spider_guard", label: "Spider Guard", position_name: "guard"},
  %{name: "lapel_guard", label: "Lapel Guard(s)", position_name: "guard"},
  %{name: "lasso_guard", label: "K Guard", position_name: "guard"},

  # Mount subpositions
  %{name: "high_mount", label: "High Mount", position_name: "mount"},
  %{name: "low_mount", label: "Low Mount", position_name: "mount"},
  %{name: "s_mount", label: "S Mount", position_name: "mount"},

  # Side control subpositions
  %{name: "standard_side_control", label: "Standard Side Control", position_name: "side_control"},
  %{name: "north_south", label: "North-South", position_name: "side_control"},
  %{name: "reverse_kesa_gatame", label: "Reverse Kesa Gatame", position_name: "side_control"},
  %{name: "kesa-gatame", label: "Kesa Gatame", position_name: "side_control"},
  %{name: "knee_on_belly", label: "Knee-On-Belly", position_name: "side_control"},
  # Back subpositions
  %{name: "back_mount", label: "Back Mount (Hooks/Body Triangle)", position_name: "back"},
  %{name: "back_crucifix", label: "Crucifix (Back)", position_name: "back"},

  # Leg Entanglement
  %{name: "ashi_garami", label: "Ashi Garami", position_name: "leg_entanglement"},
  %{name: "fifty_fifty", label: "50/50", position_name: "leg_entanglement"},
  %{name: "cross_ashi_garami", label: "Cross Ashi Garami", position_name: "leg_entanglement"},
  %{name: "berimbolo", label: "Berimbolo", position_name: "leg_entanglement"},
  %{name: "inside_ashi_garami", label: "Inside Ashi Garami (Saddle)", position_name: "leg_entanglement"},
  %{name: "double_outside_ashi_garami", label: "Double Outside Ashi", position_name: "leg_entanglement"},

]

for sub_position <- sub_positions do
  Ash.Seed.seed!(SubPosition, sub_position, actor: dev_user)
end

# Actions
actions = [
  %{name: "transitions", label: "Transitions"},
  %{name: "sweeps", label: "Sweeps"},
  %{name: "takedowns", label: "Takedowns"},
  %{name: "submissions", label: "Submissions"},
  %{name: "escapes", label: "Escapes"},
  %{name: "entries", label: "Entries"},
  %{name: "passes", label: "Passes"},
  %{name: "reversals", label: "Reversals"}
]

for action <- actions do
  Ash.Seed.seed!(Action, action, actor: dev_user)
end

# Action Position Orientations - associating actions with positions and orientations
action_orientation_positions = [
  # Standing
  {"standing", "offense", "takedowns"},
  {"standing", "offense", "entries"},
  {"standing", "offense", "transitions"},
  {"standing", "defense", "takedowns"},
  {"standing", "defense", "transitions"},

  # Guard
  {"guard", "bottom", "sweeps"},
  {"guard", "bottom", "submissions"},
  {"guard", "bottom", "transitions"},
  {"guard", "bottom", "entries"},
  {"guard", "bottom", "escapes"},
  {"guard", "bottom", "takedowns"},

  {"guard", "top", "submissions"},
  {"guard", "top", "transitions"},
  {"guard", "top", "passes"},

  # Mount
  {"mount", "bottom", "escapes"},
  {"mount", "top", "submissions"},
  {"mount", "top", "transitions"},

  # Side Control
  {"side_control", "bottom", "submissions"},
  {"side_control", "bottom", "reversals"},
  {"side_control", "bottom", "escapes"},
  {"side_control", "top", "submissions"},
  {"side_control", "top", "transitions"},

  # Back
  {"back", "inferior", "submissions"},
  {"back", "bottom", "escapes"},
  {"back", "superior", "submissions"},
  {"back", "superior", "transitions"},

  # Leg Entanglement
  {"leg_entanglement", "superior", "submissions"},
  {"leg_entanglement", "superior", "transitions"},
  {"leg_entanglement", "superior", "entries"},
  {"leg_entanglement", "inferior", "transitions"},
  {"leg_entanglement", "inferior", "escapes"},
]

# NOTE: This data structure needs to be updated to map position+orientation to actions
# instead of positions to actions (e.g., {"guard", "bottom", "sweeps"})
for {pos, ori, action} <- action_orientation_positions do
  Ash.Seed.seed!(ActionPositionOrientation, %{position_name: pos, orientation_name: ori, action_name: action}, actor: dev_user)
end

# ==========================================
# STEP 3: Load Additional Data from SQL
# ==========================================
# Load techniques, videos, and other user-generated content from SQL files

# if File.exists?("priv/repo/sql_data") and File.dir?("priv/repo/sql_data") do
#   FosBjj.Repo.SqlLoader.load_all()
# end

# IO.puts("\n✓ Database seeding complete!\n")
