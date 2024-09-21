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
  @stageId6 "stage-id-6"
  @stageId7 "stage-id-7"
  @stageId8 "stage-id-8"
  @stageId9 "stage-id-9"
  @stageId10 "stage-id-10"

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
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId1}"}, id: :stage_1_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId2}"}, id: :stage_2_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId3}"}, id: :stage_3_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId4}"}, id: :stage_4_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId5}"}, id: :stage_5_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId6}"}, id: :stage_6_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId7}"}, id: :stage_7_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId8}"}, id: :stage_8_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId9}"}, id: :stage_9_task),
      # Supervisor.child_spec({SpotliveWeb.StageStateMachine, "#{@stageId10}"}, id: :stage_10_task)
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
    config6 = Spotlive.StageConfigs.default_config("#{@stageId6}")
    config7 = Spotlive.StageConfigs.default_config("#{@stageId7}")
    config8 = Spotlive.StageConfigs.default_config("#{@stageId8}")
    config9 = Spotlive.StageConfigs.default_config("#{@stageId9}")
    config10 = Spotlive.StageConfigs.default_config("#{@stageId10}")

    opts = [strategy: :one_for_one, name: Spotlive.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Logger.info("Supervisor started successfully with PID: #{inspect(pid)}")
        Spotlive.StageMemoryService.init_config("#{@stageId1}", config1)
        # Spotlive.StageMemoryService.init_config("#{@stageId2}", config2)
        # Spotlive.StageMemoryService.init_config("#{@stageId3}", config3)
        # Spotlive.StageMemoryService.init_config("#{@stageId4}", config4)
        # Spotlive.StageMemoryService.init_config("#{@stageId5}", config5)
        # Spotlive.StageMemoryService.init_config("#{@stageId6}", config6)
        # Spotlive.StageMemoryService.init_config("#{@stageId7}", config7)
        # Spotlive.StageMemoryService.init_config("#{@stageId8}", config8)
        # Spotlive.StageMemoryService.init_config("#{@stageId9}", config9)
        # Spotlive.StageMemoryService.init_config("#{@stageId10}", config10)
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
