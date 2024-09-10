defmodule Spotlive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    redis_url = System.get_env("REDIS_CONNECTION_URL") || "redis://localhost:6374"
    children = [
      SpotliveWeb.Telemetry,
      Spotlive.Repo,
      {DNSCluster, query: Application.get_env(:spotlive, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Spotlive.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Spotlive.Finch},
      # Start a worker by calling: Spotlive.Worker.start_link(arg)
      # {Spotlive.Worker, arg},
      # Start to serve requests, typically the last entry
      SpotliveWeb.Endpoint,
      {Redix, {redis_url, [name: :redix]}},
      # Task for stage-id-1 with a unique ID
      Supervisor.child_spec({Task, fn -> SpotliveWeb.StageStateMachine.generate_round("stage-id-1") end}, id: :stage_1_task),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Spotlive.Supervisor]
    :ets.new(:round_lookup,   [:named_table, :public])
    :ets.new(:session_lookup,   [:named_table, :public])
    :ets.new(:stage_lookup,   [:named_table, :public])
    opts = [strategy: :one_for_one, name: Spotlive.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SpotliveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
