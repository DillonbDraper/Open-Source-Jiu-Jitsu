defmodule Mix.Tasks.ConfigData.Sync do
  use Mix.Task

  @shortdoc "Syncs static config data into Ash resources"

  @moduledoc """
  Synchronizes code-defined config data into the database.

      mix config_data.sync
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    FosBjj.ConfigData.sync_all()
    Mix.shell().info("Config data sync complete")
  end
end
