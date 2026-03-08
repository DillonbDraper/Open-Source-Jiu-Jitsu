defmodule FosBjj.Accounts.UserVideoReportTest do
  use FosBjj.DataCase, async: true

  import FosBjj.Fixtures

  alias FosBjj.Accounts.VideoReportReason
  alias FosBjj.ConfigData
  alias FosBjj.Accounts.UserVideoReport

  setup do
    :ok = ConfigData.sync(VideoReportReason)
    :ok
  end

  test "submit creates a video report for the acting user" do
    reporter = user_fixture(%{confirmed: true})
    video = video_fixture()

    report =
      Ash.create!(
        UserVideoReport,
        %{
          reason_name: "broken_link",
          message: "Video no longer plays",
          video_id: video.id
        },
        action: :submit,
        actor: reporter
      )

    assert report.user_id == reporter.id
    assert report.video_id == video.id
    assert report.reason_name == "broken_link"
    assert report.resolved == false
  end

  test "resolve marks report resolved with outcome and admin reason" do
    reporter = user_fixture(%{confirmed: true})
    admin = user_fixture(%{confirmed: true, role: "admin"})
    video = video_fixture()

    report =
      Ash.create!(
        UserVideoReport,
        %{reason_name: "duplicate", video_id: video.id, message: "Already exists in database"},
        action: :submit,
        actor: reporter
      )

    resolved =
      Ash.update!(
        report,
        %{
          admin_resolution_reason: "Duplicate matches an archived instructional copy",
          resolution_outcome: :kept
        },
        action: :resolve,
        actor: admin
      )

    assert resolved.resolved == true
    assert resolved.resolution_outcome == :kept
    assert resolved.admin_resolution_reason =~ "Duplicate matches"
  end
end
