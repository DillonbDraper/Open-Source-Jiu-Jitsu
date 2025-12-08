defmodule FosBjj.JiuJitsu.SubPosition do
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

    attribute :position_name, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :position, FosBjj.JiuJitsu.Position do
      source_attribute :position_name
      destination_attribute :name
      public? true
    end
  end

  # Static data for subpositions
  def data do
    [
      # Guard subpositions
      %{name: "closed_guard", label: "Closed Guard", position_name: "guard"},
      %{name: "open_guard", label: "Open Guard", position_name: "guard"},
      %{name: "half_guard", label: "Half Guard", position_name: "guard"},
      %{name: "butterfly_guard", label: "Butterfly Guard", position_name: "guard"},
      %{name: "de_la_riva_guard", label: "De La Riva Guard", position_name: "guard"},
      %{name: "reverse_de_la_riva_guard", label: "Reverse De La Riva Guard", position_name: "guard"},
      %{name: "spider_guard", label: "Spider Guard", position_name: "guard"},
      %{name: "lapel_guard", label: "Lapel Guard(s)", position_name: "guard"},
      %{name: "lasso_guard", label: "K Guard", position_name: "guard"},
      %{name: "berimbolo", label: "Berimbolo", position_name: "guard"},

      # Mount subpositions
      %{name: "high_mount", label: "High Mount", position_name: "mount"},
      %{name: "low_mount", label: "Low Mount", position_name: "mount"},
      %{name: "s_mount", label: "S Mount", position_name: "mount"},

      # Side control subpositions
      %{name: "standard_side_control", label: "Standard Side Control", position_name: "side_control"},
      %{name: "north_south", label: "North-South", position_name: "side_control"},
      %{name: "reverse_kesa_gatame", label: "Reverse Kesa Gatame", position_name: "side_control"},
      %{name: "kesa-gatame", label: "Kesa Gatame", position_name: "side_control"},

      # Back subpositions
      %{name: "back_mount", label: "Back Mount (Hooks/Body Triangle)", position_name: "back"},
      %{name: "back_crucifix", label: "Crucifix (Back)", position_name: "back"}
    ]
  end
end
