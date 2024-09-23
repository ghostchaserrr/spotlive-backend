defmodule SpotliveWeb.StageStateMachine do
  use GenServer
  require Logger
  alias Spotlive.StageMemoryService
  alias Spotlive.StageConfigs
  alias Spotlive.Algos.StagePerformerSelector
  alias Spotlive.UserDatabaseService

  def start_link(stageId) do
    GenServer.start_link(__MODULE__, stageId, name: via_tuple(stageId))
  end

  def via_tuple(stageId), do: {:via, Registry, {SpotliveWeb.StageRegistry, stageId}}

  @impl true
  def init(stageId) do
    GenServer.cast(via_tuple(stageId), :init)

    {:ok, %{stage_id: stageId}}
  end

  @impl true
  def handle_cast(:init, state = %{stage_id: stageId}) do
    start(stageId)
    {:noreply, state}
  end

  defp extract_phase_time(stageId, phase) do
    config = StageMemoryService.get_config(stageId)
    phase = Map.get(config, "#{phase}")
  end

  defp get_topic(roundId) do
    "stage:#{roundId}"
  end

  defp handle_seating_phase(stageId, roundId) do
    SpotliveWeb.Endpoint.broadcast(get_topic(roundId), "round:update", %{
      phase: "seating",
      roundId: roundId
    })

    time = extract_phase_time(stageId, "seating")

    Process.sleep(time)
    Logger.debug("phase ended: seating #{stageId} #{roundId}")

    # case. once sitting phase ends we check current player cound
    userIds = StageMemoryService.read_stage_userIds(roundId)
    users = UserDatabaseService.bulk_get_users_by_ids(userIds)

    case userIds do
      [] ->
        Logger.debug("no users: #{inspect(users)}")

        case set_round_phase(stageId, roundId, "preparing") do
          true ->
            move_game_state(stageId)

          false ->
            Logger.error("Failed to initialize round (#{roundId}) in 'preparing' phase.")
            :exit
        end

      userIds ->
        Logger.debug("round stage users: #{inspect(users)}")
        payload = StagePerformerSelector.pickPerformer(roundId, userIds)
        userId = Map.get(payload, :userId)
        user = Enum.find(users, fn %{:id => id} -> id == userId end)
        username = Map.get(user, :username)
        Logger.info("stage performer: #{userId} #{username} #{stageId} #{roundId}")

        case StageMemoryService.select_performer(roundId, userId, username) do
          true ->
            # case. broadcast message to lobby that performer has been selected
            SpotliveWeb.Endpoint.broadcast(get_topic(roundId), "select:performer", %{
              roundId: roundId,
              session: user
            })

            case set_round_phase(stageId, roundId, "preparing") do
              true ->
                move_game_state(stageId)

              false ->
                :exit
            end

          false ->
            :exit
        end
    end
  end

  defp handle_preparing_phase(stageId, roundId) do
    SpotliveWeb.Endpoint.broadcast(get_topic(roundId), "round:update", %{
      phase: "preparing",
      roundId: roundId
    })

    time = extract_phase_time(stageId, "preparing")
    Process.sleep(time)

    Logger.debug("phase ended: preparing #{stageId} #{roundId}")

    case set_round_phase(stageId, roundId, "performing") do
      true ->
        move_game_state(stageId)

      false ->
        :exit
    end
  end

  defp handle_performing_phase(stageId, roundId) do
    SpotliveWeb.Endpoint.broadcast(get_topic(roundId), "round:update", %{
      phase: "performing",
      roundId: roundId
    })

    time = extract_phase_time(stageId, "performing")
    Process.sleep(time)

    Logger.debug("phase ended: performing #{stageId} #{roundId}")

    case set_round_phase(stageId, roundId, "feedback") do
      true ->
        move_game_state(stageId)

      false ->
        :exit
    end
  end

  defp handle_feedback_phase(stageId, roundId) do
    SpotliveWeb.Endpoint.broadcast(get_topic(roundId), "round:update", %{
      phase: "feedback",
      roundId: roundId
    })

    time = extract_phase_time(stageId, "feedback")
    Process.sleep(time)

    Logger.debug("phase ended: feedback #{stageId} #{roundId}")

    case set_round_phase(stageId, roundId, "finish") do
      true ->
        move_game_state(stageId)

      false ->
        Logger.error("Failed to initialize round (#{roundId}) in 'preparing' phase.")
        :exit
    end
  end

  defp handle_finish_phase(stageId, roundId) do
    newRoundId = init_live_round()

    SpotliveWeb.Endpoint.broadcast(get_topic(roundId), "round:update", %{
      phase: "finish",
      roundId: newRoundId
    })

    Logger.debug("round init: #{stageId} #{newRoundId}")

    Process.sleep(5000)

    StageMemoryService.delete_round_data(stageId)

    case set_round_phase(stageId, newRoundId, "seating") do
      true ->
        move_game_state(stageId)

      false ->
        :exit
    end
  end

  def move_game_state(stageId) do
    case StageMemoryService.read_live_round(stageId) do
      state ->
        phase = Map.get(state, :phase)
        roundId = Map.get(state, :roundId)

        cond do
          phase == "seating" -> handle_seating_phase(stageId, roundId)
          phase == "preparing" -> handle_preparing_phase(stageId, roundId)
          phase == "performing" -> handle_performing_phase(stageId, roundId)
          phase == "feedback" -> handle_feedback_phase(stageId, roundId)
          phase == "finish" -> handle_finish_phase(stageId, roundId)
        end

      {:error, reason} ->
        :exit
    end
  end

  defp set_round_phase(
         stageId,
         roundId,
         phase
       ) do
    case StageMemoryService.store_or_update_live_round(stageId, roundId, phase) do
      {:ok, message} ->
        true

      {:error, reason} ->
        false
    end
  end

  defp init_live_round() do
    roundId = Ecto.UUID.generate()
    roundId
  end

  def start(stageId) do
    roundId = init_live_round()

    # case. start fresh round
    StageMemoryService.delete_round_data(stageId)

    SpotliveWeb.Endpoint.broadcast(get_topic(roundId), "round:update", %{
      phase: "seating",
      roundId: roundId
    })

    # case. move round to seating phase
    case set_round_phase(stageId, roundId, "seating") do
      true ->
        move_game_state(stageId)

      false ->
        :exit
    end
  end
end
