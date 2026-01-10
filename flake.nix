{
  description = "Nix flake for FOS-BJJ App development";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          });
    in
    {
      overlays.default = final: prev: rec {
        erlang = prev.beam.interpreters.erlang_28;
        pkgs-beam = final.beam.packagesWith erlang;
        elixir = final.beamMinimal28Packages.elixir_1_19;
      };

      devShells = forEachSupportedSystem (
        { pkgs }:
        let
          # Niceties I find helpful for local development.  Completely optional to use.  If you
          # want to use and do not use a db container, just define a PGDATA env var where you keep your db
          dbstart = pkgs.writeShellScriptBin "dbstart" ''
            if [ ! -d "$PGDATA" ]; then
              echo "Initializing PostgreSQL database at $PGDATA..."
              ${pkgs.postgresql_18}/bin/initdb -D "$PGDATA" --no-locale --encoding=UTF8
            fi

            if ! ${pkgs.postgresql_18}/bin/pg_ctl -D "$PGDATA" status >/dev/null; then
              echo "Starting PostgreSQL..."
              ${pkgs.postgresql_18}/bin/pg_ctl -D "$PGDATA" -l "$PGDATA/postgres.log" -o "-k '$PGHOST'" start
            else
              echo "PostgreSQL is already running."
            fi
          '';

          dbstop = pkgs.writeShellScriptBin "dbstop" ''
            ${pkgs.postgresql_18}/bin/pg_ctl -D "$PGDATA" stop
          '';

          dbstatus = pkgs.writeShellScriptBin "dbstatus" ''
            ${pkgs.postgresql_18}/bin/pg_ctl -D "$PGDATA" status
          '';
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              elixir
              git
              postgresql_18
              nodejs_25
              tailwindcss_4
              dbstart
              dbstop
              dbstatus
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [
              gigalixir
              inotify-tools
              libnotify
            ]) ++ pkgs.lib.optionals pkgs.stdenv.isDarwin (with pkgs; [
              terminal-notifier
            ]);

            shellHook = ''
              export PGHOST=/tmp

              if [ -z "$PGDATA" ]; then
                export PGDATA="$PWD/.nix-data/db"
              fi

              # Optional: Ensure the directory exists
              mkdir -p "$PGDATA"

              echo "Environment loaded."
              echo "Postgres Data Path: $PGDATA"
            '';
          };
        }
      );
    };
}
