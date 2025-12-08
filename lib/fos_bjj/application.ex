defmodule FosBjj.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FosBjjWeb.Telemetry,
      FosBjj.Repo,
      {DNSCluster, query: Application.get_env(:fos_bjj, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FosBjj.PubSub},
      # Start a worker by calling: FosBjj.Worker.start_link(arg)
      # {FosBjj.Worker, arg},
      # Start to serve requests, typically the last entry
      FosBjjWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :fos_bjj]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FosBjj.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FosBjjWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
