defmodule FosBjj.Accounts.UserRoleHelpersTest do
  use ExUnit.Case, async: true

  alias FosBjj.Accounts.User

  test "verified?/1 checks confirmed_at" do
    verified = struct(User, confirmed_at: DateTime.utc_now())
    unverified = struct(User, confirmed_at: nil)

    assert User.verified?(verified)
    refute User.verified?(unverified)
  end

  test "admin?/1 requires verified admin" do
    verified_admin = struct(User, role_name: "admin", confirmed_at: DateTime.utc_now())
    unverified_admin = struct(User, role_name: "admin", confirmed_at: nil)
    verified_student = struct(User, role_name: "student", confirmed_at: DateTime.utc_now())

    assert User.admin?(verified_admin)
    refute User.admin?(unverified_admin)
    refute User.admin?(verified_student)
  end

  test "coach?/1 requires verified coach" do
    verified_coach = struct(User, role_name: "coach", confirmed_at: DateTime.utc_now())
    unverified_coach = struct(User, role_name: "coach", confirmed_at: nil)

    assert User.coach?(verified_coach)
    refute User.coach?(unverified_coach)
  end

  test "coach_or_admin?/1 requires verified coach, contributor, or admin" do
    verified_admin = struct(User, role_name: "admin", confirmed_at: DateTime.utc_now())
    verified_coach = struct(User, role_name: "coach", confirmed_at: DateTime.utc_now())

    verified_contributor =
      struct(User, role_name: "contributor", confirmed_at: DateTime.utc_now())

    verified_student = struct(User, role_name: "student", confirmed_at: DateTime.utc_now())

    assert User.coach_or_admin?(verified_admin)
    assert User.coach_or_admin?(verified_coach)
    assert User.coach_or_admin?(verified_contributor)
    refute User.coach_or_admin?(verified_student)
  end

  test "contributor_application_eligible?/1 respects belt and experience" do
    assert User.contributor_application_eligible?(%{
             bjj_belt: :black,
             other_high_level_experience: false
           })

    assert User.contributor_application_eligible?(%{bjj_belt: "black"})
    assert User.contributor_application_eligible?(%{other_high_level_experience: true})

    refute User.contributor_application_eligible?(%{
             bjj_belt: :blue,
             other_high_level_experience: false
           })
  end
end
