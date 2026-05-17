defmodule FosBjj.Repo.Migrations.AddVideoCountPerformanceIndexes do
  use Ecto.Migration

  def up do
    create index(:video_techniques, [:technique_id])
    create index(:techniques, [:sub_position_name])
    create index(:videos, [:deleted_at], where: "deleted_at IS NOT NULL")
  end

  def down do
    drop index(:videos, [:deleted_at])
    drop index(:techniques, [:sub_position_name])
    drop index(:video_techniques, [:technique_id])
  end
end
