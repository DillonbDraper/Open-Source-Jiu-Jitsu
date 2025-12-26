defmodule FosBjj.Repo.SqlLoader do
  @moduledoc """
  Loads seed data from SQL files into the database.

  This module executes SQL dump files in a specific order to maintain
  referential integrity. SQL files should be placed in priv/repo/sql_data/

  ## Usage

      FosBjj.Repo.SqlLoader.load_all()

  Or load specific files:

      FosBjj.Repo.SqlLoader.execute_sql_file("grips.sql")
  """

  alias Ecto.Adapters.SQL
  alias FosBjj.Repo

  @sql_dir "priv/repo/sql_data"

  @doc """
  Loads SQL Files

  Note: Make sure to set an actor context before calling this if your
  tables have created_by_id or other audit fields:

      Ash.set_actor(user)
      FosBjj.Repo.SqlLoader.load_all()
  """
  def load_all do
    IO.puts("\n=== Loading data from SQL files ===\n")

    sql_files = [
      # Main content tables
      "techniques.sql",
      "videos.sql",

      # Many-to-many join tables
      "technique_positions.sql",
      "technique_sub_positions.sql",
      "video_grips.sql",
      "video_techniques.sql"
    ]

    results =
      Enum.map(sql_files, fn filename ->
        execute_sql_file(filename)
      end)

    success_count = Enum.count(results, &(&1 == :ok))
    total_count = Enum.count(results)

    IO.puts("\n✓ Loaded #{success_count}/#{total_count} SQL files successfully")
    
    # Reset sequences after loading data with explicit IDs
    reset_sequences()
    
    IO.puts("")
  end

  @doc """
  Executes a single SQL file from the sql_data directory.

  Returns :ok if successful, :skip if file doesn't exist, or raises on error.
  """
  def execute_sql_file(filename) do
    sql_path = Path.join(@sql_dir, filename)

    if File.exists?(sql_path) do
      IO.write("  Loading #{filename}... ")

      sql_content = File.read!(sql_path)

      # Split by semicolons to handle multiple statements
      # Filter out empty statements
      statements =
        sql_content
        |> String.split(";")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      # Execute each statement
      Enum.each(statements, fn statement ->
        SQL.query!(Repo, statement)
      end)

      IO.puts("✓")
      :ok
    else
      IO.puts("  Skipping #{filename} (not found)")
      :skip
    end
  rescue
    e ->
      IO.puts("✗ ERROR")
      IO.puts("  Failed to execute #{filename}: #{Exception.message(e)}")
      reraise e, __STACKTRACE__
  end

  @doc """
  Resets PostgreSQL sequences for all tables that have serial/bigserial primary keys.

  This is necessary after loading data with explicit IDs because PostgreSQL
  sequences don't automatically advance when you insert with explicit IDs.
  
  Without this, the next INSERT would try to use an ID that already exists,
  causing a duplicate key error.
  """
  def reset_sequences do
    IO.puts("\n=== Resetting sequences ===")
    
    tables = [
      "techniques",
      "videos",
      "technique_positions",
      "technique_sub_positions",
      "video_grips",
      "video_techniques"
    ]
    
    Enum.each(tables, fn table ->
      sequence_name = "#{table}_id_seq"
      
      try do
        # Get the max ID from the table
        case SQL.query(Repo, "SELECT MAX(id) FROM #{table}") do
          {:ok, %{rows: [[nil]]}} ->
            # Table is empty, no need to reset
            :ok
            
          {:ok, %{rows: [[max_id]]}} when is_integer(max_id) ->
            # Set the sequence to max_id so next value will be max_id + 1
            SQL.query!(Repo, "SELECT setval('#{sequence_name}', $1, true)", [max_id])
            IO.puts("  ✓ Reset #{table} sequence to #{max_id + 1}")
            
          {:error, _} ->
            # Table might not exist or have an id column, skip silently
            :ok
        end
      rescue
        _ ->
          # Sequence might not exist or query failed, skip silently
          :ok
      end
    end)
  end

  @doc """
  Exports current database tables to SQL files for seeding.

  This is useful for creating seed data from an existing database.
  Run this with: mix run -e "FosBjj.Repo.SqlLoader.export_to_sql()"
  """
  def export_to_sql do
    IO.puts("\n=== Exporting database to SQL files ===\n")

    # Ensure directory exists
    File.mkdir_p!(@sql_dir)

    tables = [
      "techniques",
      "videos",
      "technique_positions",
      "technique_sub_positions",
      "video_grips",
      "video_techniques"
    ]

    Enum.each(tables, &export_table/1)

    IO.puts("\n✓ Export complete! SQL files are in #{@sql_dir}/\n")
    IO.puts("Note: User/authentication tables were not exported for security.")
  end

  defp export_table(table_name) do
    IO.write("  Exporting #{table_name}... ")

    # Get all rows from the table
    result = SQL.query!(Repo, "SELECT * FROM #{table_name}")

    if result.num_rows == 0 do
      IO.puts("(empty)")
      # Create an empty file with just a comment
      sql_content = "-- #{table_name} (no data)\n"
      File.write!(Path.join(@sql_dir, "#{table_name}.sql"), sql_content)
    else
      columns = result.columns
      rows = result.rows

      # Build INSERT statements
      sql_content = build_insert_statements(table_name, columns, rows)

      # Write to file
      File.write!(Path.join(@sql_dir, "#{table_name}.sql"), sql_content)

      IO.puts("✓ (#{result.num_rows} rows)")
    end
  rescue
    e ->
      IO.puts("✗ ERROR: #{Exception.message(e)}")
  end

  defp build_insert_statements(table_name, columns, rows) do
    header = """
    -- #{table_name}
    -- Generated at #{DateTime.utc_now()}
    -- Rows: #{length(rows)}

    """

    # Build column list
    column_list = Enum.join(columns, ", ")

    # Build value rows
    value_rows =
      Enum.map(rows, fn row ->
        values =
          row
          |> Enum.map_join(", ", &format_sql_value/1)

        "  (#{values})"
      end)
      |> Enum.join(",\n")

    # Use ON CONFLICT DO NOTHING for idempotency
    insert_statement = """
    INSERT INTO #{table_name} (#{column_list}) VALUES
    #{value_rows}
    ON CONFLICT DO NOTHING;
    """

    header <> insert_statement
  end

  defp format_sql_value(nil), do: "NULL"

  defp format_sql_value(value) when is_binary(value) do
    # Escape single quotes
    escaped = String.replace(value, "'", "''")
    "'#{escaped}'"
  end

  defp format_sql_value(value) when is_boolean(value), do: to_string(value)
  defp format_sql_value(value) when is_number(value), do: to_string(value)
  defp format_sql_value(%DateTime{} = dt), do: "'#{DateTime.to_iso8601(dt)}'"
  defp format_sql_value(%NaiveDateTime{} = dt), do: "'#{NaiveDateTime.to_iso8601(dt)}'"
  defp format_sql_value(%Date{} = date), do: "'#{Date.to_iso8601(date)}'"
  defp format_sql_value(value), do: "'#{inspect(value)}'"
end
