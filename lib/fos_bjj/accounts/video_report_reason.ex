defmodule FosBjj.Accounts.VideoReportReason do
  use Ash.Resource,
    otp_app: :fos_bjj,
    domain: FosBjj.Accounts,
    data_layer: AshPostgres.DataLayer

  use FosBjj.ConfigData.Schema

  postgres do
    table("video_report_reasons")
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
    has_many :user_video_reports, FosBjj.Accounts.UserVideoReport do
      source_attribute(:name)
      destination_attribute(:reason_name)
      public?(true)
    end
  end

  @config_values [
    %{name: "duplicate", label: "Duplicate"},
    %{name: "low_quality", label: "Low Quality"},
    %{name: "broken_link", label: "Broken Link"},
    %{name: "wrong_category", label: "Wrong Category/Location in Technique Tree"},
    %{name: "inappropriate_off_topic", label: "Inappropriate / Off Topic"}
  ]

  @impl true
  def config_values, do: @config_values
end
