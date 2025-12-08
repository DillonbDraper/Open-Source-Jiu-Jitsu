defmodule FosBjj.JiuJitsu.Grip do
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

  # Static data for grips
  def data do
    [
      %{name: "two_on_one", label: "2 On 1"},
      %{name: "collar_sleeve", label: "Collar & Sleeve"},
      %{name: "belt_grip", label: "Belt Grip"},
      %{name: "over_under", label: "Over/Under"},
      %{name: "cross_grip", label: "Cross Grip"},
      %{name: "over_hook", label: "Over Hook"},
      %{name: "under_hook", label: "Under Hook"},
      %{name: "one_on_one", label: "1 On 1"},
      %{name: "collar_elbow", label: "Collar & Elbow"},
      %{name: "tricep", label: "Tricep"},
      %{name: "cross_collar", label: "Cross Collar"},
    ]
  end
end
