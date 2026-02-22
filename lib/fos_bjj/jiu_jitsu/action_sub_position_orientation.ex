defmodule FosBjj.JiuJitsu.ActionSubPositionOrientation do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema,
    key_fields: [:action_name, :sub_position_name, :orientation_name]

  postgres do
    table("action_sub_position_orientations")
    repo(FosBjj.Repo)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
  end

  attributes do
    attribute :action_name, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
    end

    attribute :sub_position_name, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
    end

    attribute :orientation_name, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :action, FosBjj.JiuJitsu.Action do
      source_attribute(:action_name)
      destination_attribute(:name)
      attribute_type(:string)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :sub_position, FosBjj.JiuJitsu.SubPosition do
      source_attribute(:sub_position_name)
      destination_attribute(:name)
      attribute_type(:string)
      allow_nil?(false)
      public?(true)
    end

    belongs_to :orientation, FosBjj.JiuJitsu.Orientation do
      source_attribute(:orientation_name)
      destination_attribute(:name)
      attribute_type(:string)
      allow_nil?(false)
      public?(true)
    end
  end

  @config_triples [
    {"upper_body", "offense", "takedowns"},
    {"upper_body", "offense", "entries"},
    {"upper_body", "offense", "transitions"},
    {"upper_body", "offense", "setups"},
    {"upper_body", "defense", "transitions"},
    {"upper_body", "defense", "escapes"},
    {"leg_grab", "offense", "takedowns"},
    {"leg_grab", "offense", "setups"},
    {"leg_grab", "offense", "transitions"},
    {"leg_grab", "defense", "transitions"},
    {"leg_grab", "defense", "escapes"},
    {"ashi_waza", "offense", "takedowns"},
    {"ashi_waza", "offense", "setups"},
    {"ashi_waza", "offense", "transitions"},
    {"ashi_waza", "defense", "transitions"},
    {"ashi_waza", "defense", "escapes"},
    {"ashi_waza", "offense", "takedowns"},
    {"ashi_waza", "offense", "setups"},
    {"ashi_waza", "offense", "transitions"},
    {"ashi_waza", "defense", "transitions"},
    {"closed_guard", "bottom", "sweeps"},
    {"closed_guard", "bottom", "submissions"},
    {"closed_guard", "bottom", "transitions"},
    {"closed_guard", "bottom", "entries"},
    {"closed_guard", "bottom", "escapes"},
    {"closed_guard", "bottom", "takedowns"},
    {"closed_guard", "top", "submissions"},
    {"closed_guard", "top", "breaks"},
    {"closed_guard", "top", "passes"},
    {"open_guard", "bottom", "sweeps"},
    {"open_guard", "bottom", "submissions"},
    {"open_guard", "bottom", "transitions"},
    {"open_guard", "bottom", "entries"},
    {"open_guard", "bottom", "escapes"},
    {"open_guard", "bottom", "takedowns"},
    {"open_guard", "top", "submissions"},
    {"open_guard", "top", "passes"},
    {"butterfly_guard", "bottom", "sweeps"},
    {"butterfly_guard", "bottom", "submissions"},
    {"butterfly_guard", "bottom", "transitions"},
    {"butterfly_guard", "bottom", "entries"},
    {"butterfly_guard", "bottom", "escapes"},
    {"butterfly_guard", "bottom", "takedowns"},
    {"butterfly_guard", "top", "submissions"},
    {"butterfly_guard", "top", "passes"},
    {"half_guard", "bottom", "sweeps"},
    {"half_guard", "bottom", "submissions"},
    {"half_guard", "bottom", "transitions"},
    {"half_guard", "bottom", "entries"},
    {"half_guard", "bottom", "escapes"},
    {"half_guard", "bottom", "takedowns"},
    {"half_guard", "top", "submissions"},
    {"half_guard", "top", "passes"},
    {"x_guard", "bottom", "sweeps"},
    {"x_guard", "bottom", "submissions"},
    {"x_guard", "bottom", "transitions"},
    {"x_guard", "bottom", "entries"},
    {"x_guard", "top", "submissions"},
    {"x_guard", "top", "passes"},
    {"x_guard", "top", "escapes"},
    {"k_guard", "bottom", "sweeps"},
    {"k_guard", "bottom", "submissions"},
    {"k_guard", "bottom", "transitions"},
    {"k_guard", "bottom", "entries"},
    {"k_guard", "bottom", "takedowns"},
    {"k_guard", "top", "escapes"},
    {"k_guard", "top", "passes"},
    {"k_guard", "top", "transitions"},
    {"single_leg_x_guard", "bottom", "sweeps"},
    {"single_leg_x_guard", "bottom", "submissions"},
    {"single_leg_x_guard", "bottom", "transitions"},
    {"single_leg_x_guard", "bottom", "entries"},
    {"single_leg_x_guard", "top", "escapes"},
    {"single_leg_x_guard", "top", "passes"},
    {"single_leg_x_guard", "top", "transitions"},
    {"single_leg_x_guard", "top", "submissions"},
    {"spider_guard", "bottom", "sweeps"},
    {"spider_guard", "bottom", "submissions"},
    {"spider_guard", "bottom", "transitions"},
    {"spider_guard", "bottom", "entries"},
    {"spider_guard", "bottom", "takedowns"},
    {"spider_guard", "top", "passes"},
    {"spider_guard", "top", "transitions"},
    {"spider_guard", "top", "submissions"},
    {"de_la_riva_guard", "bottom", "sweeps"},
    {"de_la_riva_guard", "bottom", "submissions"},
    {"de_la_riva_guard", "bottom", "transitions"},
    {"de_la_riva_guard", "bottom", "entries"},
    {"de_la_riva_guard", "bottom", "takedowns"},
    {"de_la_riva_guard", "top", "passes"},
    {"de_la_riva_guard", "top", "transitions"},
    {"de_la_riva_guard", "top", "submissions"},
    {"reverse_de_la_riva_guard", "bottom", "sweeps"},
    {"reverse_de_la_riva_guard", "bottom", "submissions"},
    {"reverse_de_la_riva_guard", "bottom", "transitions"},
    {"reverse_de_la_riva_guard", "bottom", "entries"},
    {"reverse_de_la_riva_guard", "bottom", "takedowns"},
    {"reverse_de_la_riva_guard", "top", "passes"},
    {"reverse_de_la_riva_guard", "top", "transitions"},
    {"lapel_guard", "bottom", "sweeps"},
    {"lapel_guard", "bottom", "submissions"},
    {"lapel_guard", "bottom", "transitions"},
    {"lapel_guard", "bottom", "entries"},
    {"lapel_guard", "bottom", "takedowns"},
    {"lapel_guard", "top", "passes"},
    {"lapel_guard", "top", "transitions"},
    {"lapel_guard", "top", "escapes"},
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
    {"low_mount", "bottom", "escapes"},
    {"low_mount", "top", "submissions"},
    {"low_mount", "top", "transitions"},
    {"low_mount", "top", "maintaining"},
    {"high_mount", "bottom", "escapes"},
    {"high_mount", "top", "submissions"},
    {"high_mount", "top", "transitions"},
    {"high_mount", "top", "maintaining"},
    {"s_mount", "bottom", "escapes"},
    {"s_mount", "top", "submissions"},
    {"s_mount", "top", "transitions"},
    {"standard_side_control", "bottom", "submissions"},
    {"standard_side_control", "bottom", "reversals"},
    {"standard_side_control", "bottom", "escapes"},
    {"standard_side_control", "top", "submissions"},
    {"standard_side_control", "top", "transitions"},
    {"standard_side_control", "top", "maintaining"},
    {"kesa_gatame", "bottom", "submissions"},
    {"kesa_gatame", "bottom", "reversals"},
    {"kesa_gatame", "bottom", "escapes"},
    {"kesa_gatame", "top", "submissions"},
    {"kesa_gatame", "top", "transitions"},
    {"kesa_gatame", "top", "maintaining"},
    {"reverse_kesa_gatame", "bottom", "submissions"},
    {"reverse_kesa_gatame", "bottom", "reversals"},
    {"reverse_kesa_gatame", "bottom", "escapes"},
    {"reverse_kesa_gatame", "top", "submissions"},
    {"reverse_kesa_gatame", "top", "transitions"},
    {"reverse_kesa_gatame", "top", "maintaining"},
    {"north_south", "bottom", "reversals"},
    {"north_south", "bottom", "escapes"},
    {"north_south", "top", "transitions"},
    {"north_south", "top", "submissions"},
    {"north_south", "top", "maintaining"},
    {"knee_on_belly", "bottom", "reversals"},
    {"knee_on_belly", "bottom", "escapes"},
    {"knee_on_belly", "top", "submissions"},
    {"knee_on_belly", "top", "transitions"},
    {"knee_on_belly", "top", "maintaining"},
    {"back_mount", "inferior", "transitions"},
    {"back_mount", "inferior", "escapes"},
    {"back_mount", "superior", "submissions"},
    {"back_mount", "superior", "transitions"},
    {"back_mount", "superior", "maintaining"},
    {"back_crucifix", "inferior", "submissions"},
    {"back_crucifix", "inferior", "transitions"},
    {"back_crucifix", "superior", "submissions"},
    {"back_crucifix", "superior", "transitions"},
    {"back_crucifix", "superior", "maintaining"},
    {"ashi_garami", "superior", "submissions"},
    {"ashi_garami", "superior", "transitions"},
    {"ashi_garami", "superior", "entries"},
    {"ashi_garami", "inferior", "transitions"},
    {"fifty_fifty", "inferior", "escapes"},
    {"fifty_fifty", "superior", "submissions"},
    {"fifty_fifty", "superior", "transitions"},
    {"fifty_fifty", "superior", "entries"},
    {"fifty_fifty", "inferior", "transitions"},
    {"cross_ashi_garami", "inferior", "escapes"},
    {"cross_ashi_garami", "superior", "submissions"},
    {"cross_ashi_garami", "superior", "transitions"},
    {"cross_ashi_garami", "superior", "entries"},
    {"cross_ashi_garami", "inferior", "transitions"},
    {"berimbolo", "inferior", "escapes"},
    {"berimbolo", "superior", "submissions"},
    {"berimbolo", "superior", "transitions"},
    {"berimbolo", "superior", "entries"},
    {"berimbolo", "inferior", "transitions"},
    {"double_outside_ashi_garami", "inferior", "escapes"},
    {"double_outside_ashi_garami", "superior", "submissions"},
    {"double_outside_ashi_garami", "superior", "transitions"},
    {"double_outside_ashi_garami", "superior", "entries"},
    {"double_outside_ashi_garami", "inferior", "transitions"},
    {"inside_ashi_garami", "inferior", "escapes"},
    {"inside_ashi_garami", "superior", "submissions"},
    {"inside_ashi_garami", "superior", "transitions"},
    {"inside_ashi_garami", "superior", "entries"},
    {"inside_ashi_garami", "inferior", "transitions"},
    {"classic_turtle", "top", "transitions"},
    {"classic_turtle", "top", "submissions"},
    {"classic_turtle", "top", "back_takes"},
    {"classic_turtle", "bottom", "reversals"},
    {"classic_turtle", "bottom", "escapes"},
    {"classic_turtle", "bottom", "transitions"},
    {"classic_turtle", "bottom", "submissions"},
    {"four_point_base", "top", "transitions"},
    {"four_point_base", "top", "submissions"},
    {"four_point_base", "top", "back_takes"},
    {"four_point_base", "bottom", "reversals"},
    {"four_point_base", "bottom", "escapes"},
    {"four_point_base", "bottom", "transitions"},
    {"four_point_base", "bottom", "submissions"}
  ]

  @impl true
  def config_values do
    @config_triples
    |> Enum.map(fn {sub_position_name, orientation_name, action_name} ->
      %{
        sub_position_name: sub_position_name,
        orientation_name: orientation_name,
        action_name: action_name
      }
    end)
    |> Enum.uniq()
  end
end
