# Open Source Jiu-Jitsu

Open Source Jiu Jitsu (OSBJJ) is a simple web app designed to organize and enable the searching of a curated collection of free Brazilian Jiu Jitsu instructional videos, with all entries approved by a verified expert.  Over time, it aims to develop into a complete educational platform for the subject.

## Installation

These instructions are for running the app locally for development.    Simply visiting the URL (forthcoming) should be how the majority of users interface with the app.

The included nix.flake should handle all needed dependencies dependencies for those using the nix package manager.  For those not using the nix package manager, a .tool-versions should point asdf/mise/your preferred installation solution towards compatible versions of erlang/elixir. 

To set up local data for development, a running postgres instance at port 5432 is required.  The version of postgres to use can be found in the flake.nix.  To run the database in a docker container, use the following command, substituting the username and password as you prefer:

```bash
docker run --name fos_bjj_db -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=fos_bjj_dev -p 5432:5432 -v postgres_data:/var/lib/postgresql -d postgres:18 
```

To run the database locally, the following commands should suffice:

Creating:
```bash
 pg_ctl init -D path/to/desired/database/location
```

Running:
```bash
pg_ctl -D path/to/database -l logfile.log start
```

Once your database and required versions of elixir/erlang are installed, set up your db with

```bash
mix ecto.setup
```

and finally run the app with 

```
iex -S mix phx.server
```

This by default runs the app at port 4000, which should be accessible in your browser at
[localhost:4000](https:localhost:4000)


## Contributing

All pull requests are welcome, as well as opening an issue if you have a desired feature or find a bug.

## License

[GPLV3](https://choosealicense.com/licenses/gpl-3.0/)
