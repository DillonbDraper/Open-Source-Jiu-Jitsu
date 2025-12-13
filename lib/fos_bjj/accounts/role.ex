defmodule FosBjj.Accounts.Role do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
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
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :label, :string do
      allow_nil? false
      public? true
    end

  end

  relationships do
    has_many :users, FosBjj.Accounts.User do
      source_attribute :name
      destination_attribute :role_name
      public? true
    end
  end

    # Static data for roles
    def data do
      [
        %{name: "admin", label: "Administrator"},
        %{name: "coach", label: "Coach"},
        %{name: "student", label: "Student"}
      ]
    end
end
