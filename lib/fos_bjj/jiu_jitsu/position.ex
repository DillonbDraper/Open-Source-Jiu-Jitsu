defmodule FosBjj.JiuJitsu.Position do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("positions")
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
  end

  aggregates do
    count :video_count, [:sub_positions, :techniques, :videos] do
      filter(expr(is_nil(deleted_at)))
    end
  end

  relationships do
    has_many :sub_positions, FosBjj.JiuJitsu.SubPosition do
      source_attribute(:name)
      destination_attribute(:position_name)
      public?(true)
    end

    many_to_many :orientations, FosBjj.JiuJitsu.Orientation do
      through(FosBjj.JiuJitsu.PositionOrientation)
      source_attribute(:name)
      destination_attribute(:name)
      source_attribute_on_join_resource(:position_name)
      destination_attribute_on_join_resource(:orientation_name)
      public?(true)
    end

    has_many :action_sub_position_orientations, FosBjj.JiuJitsu.ActionSubPositionOrientation do
      source_attribute(:name)
      destination_attribute(:sub_position_name)
      public?(true)
    end
  end

  @config_values [
    %{name: "standing", label: "Standing"},
    %{name: "guard", label: "Guard"},
    %{name: "mount", label: "Mount"},
    %{name: "side_control", label: "Side Control"},
    %{name: "back", label: "Back"},
    %{name: "leg_entanglement", label: "Leg Entanglement"},
    %{name: "turtle", label: "Turtle"}
  ]

  @impl true
  def config_values, do: @config_values
end
