[
  plugins: [
    Phoenix.LiveView.HTMLFormatter
  ],
  import_deps: [:error_tracker, :ecto, :ecto_sql, :phoenix],
  inputs: [
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/repo/*.ex{,s}",
    "priv/repo/local_data/**/*.ex{,s}"
  ],
  subdirectories: ["priv/repo/migrations", "priv/repo/config_data"],
  locals_without_parens: [
    conf: 1,
    conf: 2
  ]
]
