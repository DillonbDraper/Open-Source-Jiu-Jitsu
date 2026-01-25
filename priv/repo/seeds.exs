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

alias FosBjj.JiuJitsu.{
  Grip,
  Position,
  SubPosition,
  Orientation,
  PositionOrientation,
  Action,
  ActionSubPositionOrientation
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
  Ash.Seed.seed!(PositionOrientation, %{position_name: pos, orientation_name: ori},
    actor: dev_user
  )
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
  %{name: "lasso_guard", label: "Lasso Guard", position_name: "guard"},
  %{name: "k_guard", label: "K Guard", position_name: "guard"},

  # Mount subpositions
  %{name: "high_mount", label: "High Mount", position_name: "mount"},
  %{name: "low_mount", label: "Low Mount", position_name: "mount"},
  %{name: "s_mount", label: "S Mount", position_name: "mount"},

  # Side control subpositions
  %{name: "standard_side_control", label: "Standard Side Control", position_name: "side_control"},
  %{name: "north_south", label: "North-South", position_name: "side_control"},
  %{name: "reverse_kesa_gatame", label: "Reverse Kesa Gatame", position_name: "side_control"},
  %{name: "kesa_gatame", label: "Kesa Gatame", position_name: "side_control"},
  %{name: "knee_on_belly", label: "Knee-On-Belly", position_name: "side_control"},
  # Back subpositions
  %{name: "back_mount", label: "Back Mount (Hooks/Body Triangle)", position_name: "back"},
  %{name: "back_crucifix", label: "Crucifix (Back)", position_name: "back"},

  # Leg Entanglement
  %{name: "ashi_garami", label: "Ashi Garami", position_name: "leg_entanglement"},
  %{name: "fifty_fifty", label: "50/50", position_name: "leg_entanglement"},
  %{name: "cross_ashi_garami", label: "Cross Ashi Garami", position_name: "leg_entanglement"},
  %{name: "berimbolo", label: "Berimbolo", position_name: "leg_entanglement"},
  %{
    name: "inside_ashi_garami",
    label: "Inside Ashi Garami (Saddle)",
    position_name: "leg_entanglement"
  },
  %{
    name: "double_outside_ashi_garami",
    label: "Double Outside Ashi",
    position_name: "leg_entanglement"
  },
  %{
    name: "classic_turtle",
    label: "Classic Turtle",
    position_name: "turtle"
  },
  %{
    name: "four_point_base",
    label: "4 Point Base",
    position_name: "turtle"
  }
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
  %{name: "reversals", label: "Reversals"},
  %{name: "breaks", label: "Breaks"},
  %{name: "setups", label: "Setups"},
  %{name: "maintaining", label: "Maintaining"},
  %{name: "back_takes", label: "Back Takes"}
]

for action <- actions do
  Ash.Seed.seed!(Action, action, actor: dev_user)
end

# Action Subposition Orientations - associating actions with subpositions and orientations
action_orientation_subpositions = [
  # Standing upper-body
  {"upper_body", "offense", "takedowns"},
  {"upper_body", "offense", "entries"},
  {"upper_body", "offense", "transitions"},
  {"upper_body", "offense", "setups"},
  {"upper_body", "defense", "transitions"},
  {"upper_body", "defense", "escapes"},

  # Standing lower-body
  {"leg_grab", "offense", "takedowns"},
  {"leg_grab", "offense", "setups"},
  {"leg_grab", "offense", "transitions"},
  {"leg_grab", "defense", "transitions"},
  {"leg_grab", "defense", "escapes"},

  # Standing footsweeps
  {"ashi_waza", "offense", "takedowns"},
  {"ashi_waza", "offense", "setups"},
  {"ashi_waza", "offense", "transitions"},
  {"ashi_waza", "defense", "transitions"},
  {"ashi_waza", "defense", "escapes"},

  # Standing sacrifice
  {"ashi_waza", "offense", "takedowns"},
  {"ashi_waza", "offense", "setups"},
  {"ashi_waza", "offense", "transitions"},
  {"ashi_waza", "defense", "transitions"},

  # Closed Guard
  {"closed_guard", "bottom", "sweeps"},
  {"closed_guard", "bottom", "submissions"},
  {"closed_guard", "bottom", "transitions"},
  {"closed_guard", "bottom", "entries"},
  {"closed_guard", "bottom", "escapes"},
  {"closed_guard", "bottom", "takedowns"},
  {"closed_guard", "top", "submissions"},
  {"closed_guard", "top", "breaks"},
  {"closed_guard", "top", "passes"},

  # Open Guard
  {"open_guard", "bottom", "sweeps"},
  {"open_guard", "bottom", "submissions"},
  {"open_guard", "bottom", "transitions"},
  {"open_guard", "bottom", "entries"},
  {"open_guard", "bottom", "escapes"},
  {"open_guard", "bottom", "takedowns"},
  {"open_guard", "top", "submissions"},
  {"open_guard", "top", "passes"},

  # Butterfly Guard
  {"butterfly_guard", "bottom", "sweeps"},
  {"butterfly_guard", "bottom", "submissions"},
  {"butterfly_guard", "bottom", "transitions"},
  {"butterfly_guard", "bottom", "entries"},
  {"butterfly_guard", "bottom", "escapes"},
  {"butterfly_guard", "bottom", "takedowns"},
  {"butterfly_guard", "top", "submissions"},
  {"butterfly_guard", "top", "passes"},

  # Half Guard
  {"half_guard", "bottom", "sweeps"},
  {"half_guard", "bottom", "submissions"},
  {"half_guard", "bottom", "transitions"},
  {"half_guard", "bottom", "entries"},
  {"half_guard", "bottom", "escapes"},
  {"half_guard", "bottom", "takedowns"},
  {"half_guard", "top", "submissions"},
  {"half_guard", "top", "passes"},

  # X Guard
  {"x_guard", "bottom", "sweeps"},
  {"x_guard", "bottom", "submissions"},
  {"x_guard", "bottom", "transitions"},
  {"x_guard", "bottom", "entries"},
  {"x_guard", "top", "submissions"},
  {"x_guard", "top", "passes"},
  {"x_guard", "top", "escapes"},

  # K Guard
  {"k_guard", "bottom", "sweeps"},
  {"k_guard", "bottom", "submissions"},
  {"k_guard", "bottom", "transitions"},
  {"k_guard", "bottom", "entries"},
  {"k_guard", "bottom", "takedowns"},
  {"k_guard", "top", "escapes"},
  {"k_guard", "top", "passes"},
  {"k_guard", "top", "transitions"},

  # SLX Guard
  {"single_leg_x_guard", "bottom", "sweeps"},
  {"single_leg_x_guard", "bottom", "submissions"},
  {"single_leg_x_guard", "bottom", "transitions"},
  {"single_leg_x_guard", "bottom", "entries"},
  {"single_leg_x_guard", "top", "escapes"},
  {"single_leg_x_guard", "top", "passes"},
  {"single_leg_x_guard", "top", "transitions"},
  {"single_leg_x_guard", "top", "submissions"},

  # Spider Guard
  {"spider_guard", "bottom", "sweeps"},
  {"spider_guard", "bottom", "submissions"},
  {"spider_guard", "bottom", "transitions"},
  {"spider_guard", "bottom", "entries"},
  {"spider_guard", "bottom", "takedowns"},
  {"spider_guard", "top", "passes"},
  {"spider_guard", "top", "transitions"},
  {"spider_guard", "top", "submissions"},

  # De La Riva Guard
  {"de_la_riva_guard", "bottom", "sweeps"},
  {"de_la_riva_guard", "bottom", "submissions"},
  {"de_la_riva_guard", "bottom", "transitions"},
  {"de_la_riva_guard", "bottom", "entries"},
  {"de_la_riva_guard", "bottom", "takedowns"},
  {"de_la_riva_guard", "top", "passes"},
  {"de_la_riva_guard", "top", "transitions"},
  {"de_la_riva_guard", "top", "submissions"},

  # Reverse De La Riva Guard
  {"reverse_de_la_riva_guard", "bottom", "sweeps"},
  {"reverse_de_la_riva_guard", "bottom", "submissions"},
  {"reverse_de_la_riva_guard", "bottom", "transitions"},
  {"reverse_de_la_riva_guard", "bottom", "entries"},
  {"reverse_de_la_riva_guard", "bottom", "takedowns"},
  {"reverse_de_la_riva_guard", "top", "passes"},
  {"reverse_de_la_riva_guard", "top", "transitions"},

  # Lapel Guards
  {"lapel_guard", "bottom", "sweeps"},
  {"lapel_guard", "bottom", "submissions"},
  {"lapel_guard", "bottom", "transitions"},
  {"lapel_guard", "bottom", "entries"},
  {"lapel_guard", "bottom", "takedowns"},
  {"lapel_guard", "top", "passes"},
  {"lapel_guard", "top", "transitions"},
  {"lapel_guard", "top", "escapes"},

  # Lasso  Guard
  {"lasso_guard", "top", "submissions"},
  {"lasso_guard", "bottom", "sweeps"},
  {"lasso_guard", "bottom", "submissions"},
  {"lasso_guard", "bottom", "transitions"},
  {"lasso_guard", "bottom", "entries"},
  {"lasso_guard", "bottom", "takedowns"},
  {"lasso_guard", "top", "passes"},
  {"lasso_guard", "top", "transitions"},
  {"lasso_guard", "top", "submissions"},
  {"lasso_guard", "top", "escapes"},

  # Low Mount
  {"low_mount", "bottom", "escapes"},
  {"low_mount", "top", "submissions"},
  {"low_mount", "top", "transitions"},
  {"low_mount", "top", "maintaining"},

  # High Mount
  {"high_mount", "bottom", "escapes"},
  {"high_mount", "top", "submissions"},
  {"high_mount", "top", "transitions"},
  {"high_mount", "top", "maintaining"},

  # S-Mount
  {"s_mount", "bottom", "escapes"},
  {"s_mount", "top", "submissions"},
  {"s_mount", "top", "transitions"},

  # Standard Side Control
  {"standard_side_control", "bottom", "submissions"},
  {"standard_side_control", "bottom", "reversals"},
  {"standard_side_control", "bottom", "escapes"},
  {"standard_side_control", "top", "submissions"},
  {"standard_side_control", "top", "transitions"},
  {"standard_side_control", "top", "maintaining"},

  # Kesa Gatame
  {"kesa_gatame", "bottom", "submissions"},
  {"kesa_gatame", "bottom", "reversals"},
  {"kesa_gatame", "bottom", "escapes"},
  {"kesa_gatame", "top", "submissions"},
  {"kesa_gatame", "top", "transitions"},
  {"kesa_gatame", "top", "maintaining"},

  # Reverse Kesa Gatame
  {"reverse_kesa_gatame", "bottom", "submissions"},
  {"reverse_kesa_gatame", "bottom", "reversals"},
  {"reverse_kesa_gatame", "bottom", "escapes"},
  {"reverse_kesa_gatame", "top", "submissions"},
  {"reverse_kesa_gatame", "top", "transitions"},
  {"reverse_kesa_gatame", "top", "maintaining"},

  # North/South
  {"north_south", "bottom", "reversals"},
  {"north_south", "bottom", "escapes"},
  {"north_south", "top", "transitions"},
  {"north_south", "top", "submissions"},
  {"north_south", "top", "maintaining"},

  # Knee On Belly
  {"knee_on_belly", "bottom", "reversals"},
  {"knee_on_belly", "bottom", "escapes"},
  {"knee_on_belly", "top", "submissions"},
  {"knee_on_belly", "top", "transitions"},
  {"knee_on_belly", "top", "maintaining"},

  # Back With Hooks
  {"back_mount", "inferior", "transitions"},
  {"back_mount", "inferior", "escapes"},
  {"back_mount", "superior", "submissions"},
  {"back_mount", "superior", "transitions"},
  {"back_mount", "superior", "maintaining"},

  # Back Crucifix
  {"back_crucifix", "inferior", "submissions"},
  {"back_crucifix", "inferior", "transitions"},
  {"back_crucifix", "superior", "submissions"},
  {"back_crucifix", "superior", "transitions"},
  {"back_crucifix", "superior", "maintaining"},

  # Ashi Garami
  {"ashi_garami", "superior", "submissions"},
  {"ashi_garami", "superior", "transitions"},
  {"ashi_garami", "superior", "entries"},
  {"ashi_garami", "inferior", "transitions"},

  # 50/50
  {"fifty_fifty", "inferior", "escapes"},
  {"fifty_fifty", "superior", "submissions"},
  {"fifty_fifty", "superior", "transitions"},
  {"fifty_fifty", "superior", "entries"},
  {"fifty_fifty", "inferior", "transitions"},

  # Cross Ashi
  {"cross_ashi_garami", "inferior", "escapes"},
  {"cross_ashi_garami", "superior", "submissions"},
  {"cross_ashi_garami", "superior", "transitions"},
  {"cross_ashi_garami", "superior", "entries"},
  {"cross_ashi_garami", "inferior", "transitions"},

  # Berimbolo
  {"berimbolo", "inferior", "escapes"},
  {"berimbolo", "superior", "submissions"},
  {"berimbolo", "superior", "transitions"},
  {"berimbolo", "superior", "entries"},
  {"berimbolo", "inferior", "transitions"},

  # Double Outside Ashi
  {"double_outside_ashi_garami", "inferior", "escapes"},
  {"double_outside_ashi_garami", "superior", "submissions"},
  {"double_outside_ashi_garami", "superior", "transitions"},
  {"double_outside_ashi_garami", "superior", "entries"},
  {"double_outside_ashi_garami", "inferior", "transitions"},

  # Inside Ashi
  {"inside_ashi_garami", "inferior", "escapes"},
  {"inside_ashi_garami", "superior", "submissions"},
  {"inside_ashi_garami", "superior", "transitions"},
  {"inside_ashi_garami", "superior", "entries"},
  {"inside_ashi_garami", "inferior", "transitions"},

  # Classic Turtle
  {"classic_turtle", "top", "transitions"},
  {"classic_turtle", "top", "submissions"},
  {"classic_turtle", "top", "back_takes"},
  {"classic_turtle", "bottom", "reversals"},
  {"classic_turtle", "bottom", "escapes"},
  {"classic_turtle", "bottom", "transitions"},
  {"classic_turtle", "bottom", "submissions"},

  # Four Point Base
  {"four_point_base", "top", "transitions"},
  {"four_point_base", "top", "submissions"},
  {"four_point_base", "top", "back_takes"},
  {"four_point_base", "bottom", "reversals"},
  {"four_point_base", "bottom", "escapes"},
  {"four_point_base", "bottom", "transitions"},
  {"four_point_base", "bottom", "submissions"}
]

for {subposition, orientation, action} <- action_orientation_subpositions do
  item = %{sub_position_name: subposition, orientation_name: orientation, action_name: action}

  Ash.Seed.seed!(
    ActionSubPositionOrientation,
    item,
    actor: dev_user
  )
end

# ==========================================
# STEP 3: Load Additional Data from SQL
# ==========================================
# Load techniques, videos, and other user-generated content from SQL files
if File.exists?("priv/repo/sql_data") and File.dir?("priv/repo/sql_data") do
  FosBjj.Repo.SqlLoader.load_all()
end

IO.puts("\n✓ Database seeding complete!\n")
