defmodule FosBjj.JiuJitsu.Grip do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "grips"
    repo FosBjj.Repo
  end

  actions do
    read :read do
      primary? true
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
end
