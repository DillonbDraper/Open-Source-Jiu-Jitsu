defmodule FosBjj.JiuJitsu.Orientation do
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

  # Static data for orientations
  def data do
    [
      %{name: "top", label: "Top"},
      %{name: "bottom", label: "Bottom"},
      %{name: "superior", label: "Superior"},
      %{name: "inferior", label: "Inferior"}
    ]
  end
end
