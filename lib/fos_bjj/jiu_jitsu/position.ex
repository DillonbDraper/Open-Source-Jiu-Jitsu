defmodule FosBjj.JiuJitsu.Position do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: Ash.DataLayer.Simple

  actions do
    read :read do
      primary? true
      prepare fn query, _context ->
        data =
          data()
          |> Enum.map(fn attrs ->
            struct(__MODULE__, attrs)
          end)

        Ash.DataLayer.Simple.set_data(query, data)
      end
    end
  end

  attributes do
    attribute :name, :string do
      allow_nil? false
      public? true
      primary_key? true
    end

    attribute :label, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    has_many :sub_positions, FosBjj.JiuJitsu.SubPosition do
      source_attribute :name
      destination_attribute :position_name
      public? true
    end
  end

  # Static data for positions
  def data do
    [
      %{name: "standing", label: "Standing"},
      %{name: "guard", label: "Guard"},
      %{name: "mount", label: "Mount"},
      %{name: "side_control", label: "Side Control"},
      %{name: "back", label: "Back"},
      %{name: "knee_on_belly", label: "Knee-on-Belly"},
      %{name: "leg_entanglement", label: "Leg Entanglement"}
    ]
  end
end
