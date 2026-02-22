defmodule FosBjj.ConfigDataTest do
  use FosBjj.DataCase, async: true

  import Ecto.Query

  alias FosBjj.ConfigData
  alias FosBjj.JiuJitsu.ActionSubPositionOrientation
  alias FosBjj.JiuJitsu.Action
  alias FosBjj.JiuJitsu.Grip
  alias FosBjj.JiuJitsu.Orientation
  alias FosBjj.JiuJitsu.Position
  alias FosBjj.JiuJitsu.PositionOrientation
  alias FosBjj.JiuJitsu.SubPosition

  test "list includes config-managed resources" do
    resources = ConfigData.list()

    assert Grip in resources
    assert Position in resources
    assert Orientation in resources
    assert SubPosition in resources
    assert Action in resources
    assert PositionOrientation in resources
    assert ActionSubPositionOrientation in resources
  end

  test "sync_all is safe to run repeatedly" do
    assert :ok = ConfigData.sync_all()
    assert :ok = ConfigData.sync_all()
  end

  test "sync prunes removed rows and updates existing values" do
    Repo.insert_all("grips", [%{name: "obsolete_grip", label: "To Remove"}],
      on_conflict: :nothing
    )

    Repo.insert_all(
      "grips",
      [%{name: "two_on_one", label: "Incorrect Label"}],
      conflict_target: [:name],
      on_conflict: [set: [label: "Incorrect Label"]]
    )

    assert :ok = ConfigData.sync(Grip)

    assert Repo.one(from(g in "grips", where: g.name == "two_on_one", select: g.label)) ==
             "2 On 1"

    assert Repo.one(from(g in "grips", where: g.name == "obsolete_grip", select: count(g.name))) ==
             0
  end

  test "sync prunes unmanaged action_sub_position_orientation rows" do
    unmanaged_key = %{
      sub_position_name: "upper_body",
      orientation_name: "offense",
      action_name: "maintaining"
    }

    refute unmanaged_key in ActionSubPositionOrientation.config_values()

    Repo.insert_all("action_sub_position_orientations", [unmanaged_key], on_conflict: :nothing)

    assert Repo.one(
             from(a in "action_sub_position_orientations",
               where:
                 a.sub_position_name == ^unmanaged_key.sub_position_name and
                   a.orientation_name == ^unmanaged_key.orientation_name and
                   a.action_name == ^unmanaged_key.action_name,
               select: count()
             )
           ) == 1

    assert :ok = ConfigData.sync(ActionSubPositionOrientation)

    assert Repo.one(
             from(a in "action_sub_position_orientations",
               where:
                 a.sub_position_name == ^unmanaged_key.sub_position_name and
                   a.orientation_name == ^unmanaged_key.orientation_name and
                   a.action_name == ^unmanaged_key.action_name,
               select: count()
             )
           ) == 0
  end
end
