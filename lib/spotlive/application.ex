defmodule Spotlive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @stageId1 "stage-id-1"
  @stageId2 "stage-id-2"
  @stageId3 "stage-id-3"
  @stageId4 "stage-id-4"
  @stageId5 "stage-id-5"

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
      {Registry, keys: :unique, name: SpotliveWeb.StageRegistry},
      Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId1}"}, id: :stage_1_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId2}"}, id: :stage_2_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId3}"}, id: :stage_3_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId4}"}, id: :stage_4_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId5}"}, id: :stage_5_task)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Spotlive.Supervisor]
    :ets.new(:session_lookup, [:named_table, :public])

    config1 = Spotlive.StageConfigs.default_config("#{@stageId1}")
    config2 = Spotlive.StageConfigs.default_config("#{@stageId2}")
    config3 = Spotlive.StageConfigs.default_config("#{@stageId3}")
    config4 = Spotlive.StageConfigs.default_config("#{@stageId4}")
    config5 = Spotlive.StageConfigs.default_config("#{@stageId5}")

    opts = [strategy: :one_for_one, name: Spotlive.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("Supervisor started successfully with PID: #{inspect(pid)}")
        Spotlive.StageMemoryService.init_config("#{@stageId1}", config1)
        Spotlive.StageMemoryService.init_config("#{@stageId2}", config2)
        Spotlive.StageMemoryService.init_config("#{@stageId3}", config3)
        Spotlive.StageMemoryService.init_config("#{@stageId4}", config4)
        Spotlive.StageMemoryService.init_config("#{@stageId5}", config5)
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start supervisor. Reason: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SpotliveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
