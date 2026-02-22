defmodule FosBjj.JiuJitsu.Grip do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("grips")
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

  @config_values [
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
    %{name: "ankle_lock_grip", label: "Ankle Lock Grip"},
    %{name: "kimura_grip", label: "Kimura Grip/Double Wristlock"}
  ]

  @impl true
  def config_values, do: @config_values
end
