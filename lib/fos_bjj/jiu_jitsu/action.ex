defmodule FosBjj.JiuJitsu.Action do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("actions")
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

  relationships do
    has_many :techniques, FosBjj.JiuJitsu.Technique do
      source_attribute(:name)
      destination_attribute(:action_name)
      public?(true)
    end

    has_many :action_sub_position_orientations, FosBjj.JiuJitsu.ActionSubPositionOrientation do
      source_attribute(:name)
      destination_attribute(:action_name)
      public?(true)
    end
  end

  @config_values [
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

  @impl true
  def config_values, do: @config_values
end
