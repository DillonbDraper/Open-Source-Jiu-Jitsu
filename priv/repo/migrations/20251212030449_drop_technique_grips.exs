defmodule FosBjj.Repo.Migrations.DropTechniqueGrips do
  use Ecto.Migration

  def up do
    drop constraint(:technique_grips, "technique_grips_technique_id_fkey")
    drop table(:technique_grips)
  end

  def down do
    create table(:technique_grips, primary_key: false) do
      add :id, :bigserial, null: false, primary_key: true

      add :technique_id,
          references(:techniques,
            column: :id,
            name: "technique_grips_technique_id_fkey",
            type: :bigint,
            prefix: "public"
          ),
          null: false

      add :grip_name, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end
  end
end
