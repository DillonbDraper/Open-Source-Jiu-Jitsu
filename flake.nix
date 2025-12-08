{
  description = "Nix flake for FOS-BJJ App development";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # unstable Nixpkgs

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: rec {

        # ==== ERLANG ====

        # Use Erlang OTP 28 (latest in nixpkgs)
        erlang = prev.beam.interpreters.erlang_28;

        # ==== BEAM packages ====

        # all BEAM packages will be compile with your preferred erlang version
        pkgs-beam = final.beam.packagesWith erlang;

        # ==== Elixir ====

        elixir = final.beamMinimal28Packages.elixir_1_19;


      };


      devShells = forEachSupportedSystem (
        { pkgs }:
        let
          # for nixos, configure unix_socket_directories = '/tmp' in postresql.conf
          # create initial db with initdb path/to/db

          # Create helper scripts for PostgreSQL management
          dbstart = pkgs.writeShellScriptBin "dbstart" ''
            if [ ! -f /home/dillon/Databases/fos_bjj/postmaster.pid ]; then
              echo "Starting PostgreSQL..."
              ${pkgs.postgresql_18}/bin/pg_ctl -D /home/dillon/Databases/fos_bjj -l /home/dillon/Databases/fos_bjj/logfile start
            else
              echo "PostgreSQL is already running"
            fi
          '';

          dbstop = pkgs.writeShellScriptBin "dbstop" ''
            ${pkgs.postgresql_18}/bin/pg_ctl -D /home/dillon/Databases/fos_bjj stop
          '';

          dbstatus = pkgs.writeShellScriptBin "dbstatus" ''
            ${pkgs.postgresql_18}/bin/pg_ctl -D /home/dillon/Databases/fos_bjj status
          '';
        in
        {
          default = pkgs.mkShellNoCC {
            packages =
              with pkgs;
              [
                # use the Elixr/OTP versions defined above; will also install OTP, mix, hex, rebar3
                elixir

                # mix needs it for downloading dependencies
                git

                postgresql_18

                nodejs_25
                tailwindcss_4

                # Database management scripts
                dbstart
                dbstop
                dbstatus
              ]
              ++
                # Linux only
                pkgs.lib.optionals pkgs.stdenv.isLinux (
                  with pkgs;
                  [
                    gigalixir
                    inotify-tools
                    libnotify
                  ]
                )
              ++
                # macOS only
                pkgs.lib.optionals pkgs.stdenv.isDarwin (
                  with pkgs;
                  [
                    terminal-notifier
                  ]
                );

            shellHook = ''
              # Configure PostgreSQL to use /tmp for sockets
              export PGHOST=/tmp
              export PGDATA=/home/dillon/Databases/fos_bjj
            '';
          };
        }
      );
    };
}
