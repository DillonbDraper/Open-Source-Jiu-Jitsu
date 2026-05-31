defmodule FosBjj.JiuJitsu.VideoType do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.JiuJitsu,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("video_types")
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
    has_many :videos, FosBjj.JiuJitsu.Video do
      source_attribute(:name)
      destination_attribute(:video_type_name)
      public?(true)
    end
  end

  @config_values [
    %{name: "instructional", label: "Instructional"},
    %{name: "analysis", label: "Analysis"},
    %{name: "in_action", label: "inAction"}
  ]

  @impl true
  def config_values, do: @config_values
end
