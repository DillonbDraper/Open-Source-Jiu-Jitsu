defmodule FosBjj.JiuJitsu.SubPosition do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("sub_positions")
    repo(FosBjj.Repo)
  end

  actions do
    read :read do
      primary?(true)
    end
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
    end

    attribute :label, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :position_name, :string do
      allow_nil?(false)
      public?(true)
    end
  end

  aggregates do
    count :video_count, [:techniques, :videos] do
      filter(expr(is_nil(deleted_at)))
    end
  end

  relationships do
    belongs_to :position, FosBjj.JiuJitsu.Position do
      source_attribute(:position_name)
      destination_attribute(:name)
      public?(true)
    end

    has_many :techniques, FosBjj.JiuJitsu.Technique do
      source_attribute(:name)
      destination_attribute(:sub_position_name)
      public?(true)
    end

    has_many :action_sub_position_orientations, FosBjj.JiuJitsu.ActionSubPositionOrientation do
      source_attribute(:name)
      destination_attribute(:sub_position_name)
      public?(true)
    end
  end

  @config_values [
    %{name: "upper_body", label: "Upper Body", position_name: "standing"},
    %{name: "leg_grab", label: "Leg Grab", position_name: "standing"},
    %{name: "ashi_waza", label: "Ashi Waza", position_name: "standing"},
    %{name: "sacrifice_sutemi_waza", label: "Sacrifice (Sutemi Waza)", position_name: "standing"},
    %{name: "closed_guard", label: "Closed Guard", position_name: "guard"},
    %{name: "open_guard", label: "Open Guard", position_name: "guard"},
    %{name: "half_guard", label: "Half Guard", position_name: "guard"},
    %{name: "butterfly_guard", label: "Butterfly Guard", position_name: "guard"},
    %{name: "de_la_riva_guard", label: "De La Riva Guard", position_name: "guard"},
    %{
      name: "reverse_de_la_riva_guard",
      label: "Reverse De La Riva Guard",
      position_name: "guard"
    },
    %{name: "single_leg_x_guard", label: "Single Leg X Guard", position_name: "guard"},
    %{name: "x_guard", label: "X Guard", position_name: "guard"},
    %{name: "spider_guard", label: "Spider Guard", position_name: "guard"},
    %{name: "lapel_guard", label: "Lapel Guard(s)", position_name: "guard"},
    %{name: "lasso_guard", label: "Lasso Guard", position_name: "guard"},
    %{name: "k_guard", label: "K Guard", position_name: "guard"},
    %{name: "high_mount", label: "High Mount", position_name: "mount"},
    %{name: "low_mount", label: "Low Mount", position_name: "mount"},
    %{name: "s_mount", label: "S Mount", position_name: "mount"},
    %{name: "technical_mount", label: "Technical Mount", position_name: "mount"},
    %{
      name: "standard_side_control",
      label: "Standard Side Control",
      position_name: "side_control"
    },
    %{name: "north_south", label: "North-South", position_name: "side_control"},
    %{name: "reverse_kesa_gatame", label: "Reverse Kesa Gatame", position_name: "side_control"},
    %{name: "kesa_gatame", label: "Kesa Gatame", position_name: "side_control"},
    %{name: "knee_on_belly", label: "Knee-On-Belly", position_name: "side_control"},
    %{name: "back_mount", label: "Back Mount (Hooks/Body Triangle)", position_name: "back"},
    %{name: "back_crucifix", label: "Crucifix (Back)", position_name: "back"},
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
    %{name: "classic_turtle", label: "Classic Turtle", position_name: "turtle"},
    %{name: "four_point_base", label: "4 Point Base", position_name: "turtle"}
  ]

  @impl true
  def config_values, do: @config_values
end
