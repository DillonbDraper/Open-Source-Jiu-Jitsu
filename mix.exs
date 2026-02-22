defmodule FosBjj.MixProject do
  use Mix.Project

  def project do
    [
      app: :fos_bjj,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {FosBjj.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    deps = [
      {:error_tracker, "~> 0.7"},
      {:bcrypt_elixir, "~> 3.0"},
      {:picosat_elixir, "~> 0.2"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:mishka_chelekom, "~> 0.0", only: [:dev]},
      {:live_debugger, "~> 0.5", only: [:dev]},
      {:tidewave, "~> 0.5", only: :dev},
      {:ash_admin, "~> 0.13"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:phoenix, "~> 1.8.2"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:resend, "~> 0.4.5"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:video_link_helper, "~> 0.3.0"}
    ]

    deps ++ tailwind_dep()
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": assets_setup(),
      "assets.build": assets_build(),
      "assets.deploy": assets_deploy(),
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp nixos? do
    File.exists?("/etc/nixos/configuration.nix")
  end

  defp tailwind_dep do
    if nixos?() do
      []
    else
      [{:tailwind, "~> 0.3.1", runtime: Mix.env() == :dev}]
    end
  end

  defp assets_setup do
    if nixos?() do
      ["esbuild.install --if-missing"]
    else
      ["tailwind.install --if-missing", "esbuild.install --if-missing"]
    end
  end

  defp assets_build do
    base = ["compile"]

    tailwind =
      if nixos?() do
        "cmd --cd assets tailwindcss --input=css/app.css --output=../priv/static/assets/css/app.css"
      else
        "tailwind fos_bjj"
      end

    base ++ [tailwind, "esbuild fos_bjj"]
  end

  defp assets_deploy do
    tailwind =
      if nixos?() do
        "cmd --cd assets tailwindcss --input=css/app.css --output=../priv/static/assets/css/app.css --minify"
      else
        "tailwind fos_bjj --minify"
      end

    [tailwind, "esbuild fos_bjj --minify", "phx.digest"]
  end
end
