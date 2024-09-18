defmodule SpotliveWeb.StageStateMachine do
  use GenServer
  require Logger
  alias Spotlive.StageMemoryService
  alias Spotlive.StageConfigs

  def start_link(stageId) do
    GenServer.start_link(__MODULE__, stageId, name: via_tuple(stageId))
  end

  def via_tuple(stageId), do: {:via, Registry, {SpotliveWeb.StageRegistry, stageId}}

  @impl true
  def init(stageId) do
    Logger.info("gen server ready: #{stageId}")
    GenServer.cast(via_tuple(stageId), :init)

    {:ok, %{stage_id: stageId}}
  end

  @impl true
  def handle_cast(:init, state = %{stage_id: stageId}) do
    Logger.info("Received round start: #{stageId}")
    start(stageId)
    {:noreply, state}
  end

  defp extract_phase_time(stageId, phase) do
    config = StageMemoryService.get_config(stageId)
    phase = Map.get(config, "#{phase}")
  end

  defp handle_preparing_phase(stageId, roundId) do
    Logger.debug("current stage id (#{stageId})")
    Logger.debug("Live round (#{roundId}) is now in 'preparing' phase.")

    # case. extracing preparing phase seconds
    preparing = extract_phase_time(stageId, "preparing")

    Logger.debug("Guests are preparing for the show. Sleeping for #{preparing} milliseconds.")
    Process.sleep(preparing)

    # topic.
    stage = "stage:" <> roundId

    # phase preparing
    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "preparing", round_id: roundId})

    Logger.debug(
      "Stage ID: #{stage}. Preparing phase ending, transitioning to 'performing' phase."
    )

    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    case set_round_phase(stageId, roundId, "performing") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'performing'.")
        move_game_state(stageId)

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'performing' phase.")
        :exit
    end
  end

  defp handle_performing_phase(stageId, roundId) do
    Logger.debug("Stage #{stageId}")
    Logger.debug("Live round (#{roundId}) is now in 'performing' phase.")

    time = extract_phase_time(stageId, "performing")

    # case. extract config in milliseconds
    Logger.debug("Performer is on stage. Sleeping for #{time} milliseconds")
    Process.sleep(time)

    stage = "stage:" <> roundId

    Logger.debug(
      "Stage ID: #{stage}. performing phase ending, transitioning to 'feedbacks' phase."
    )

    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "feedbacks", round_id: roundId})

    case set_round_phase(stageId, roundId, "feedbacks") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'feedbacks'.")
        move_game_state(stageId)

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'feedbacks' phase.")
        :exit
    end
  end

  defp handle_feedback_phase(stageId, roundId) do
    Logger.debug("Stage: #{stageId}")
    Logger.debug("Live round (#{roundId}) is now in 'feedbacks' phase.")

    # Feedback phase lasts 30 seconds (mocked as 5 seconds)
    time = extract_phase_time(stageId, "feedback")
    Logger.debug("Audience providing feedback. Sleeping for #{time} mills.")
    Process.sleep(time)

    stage = "stage:" <> roundId
    Logger.debug("Stage ID: #{stage}. Feedback phase ending, transitioning to 'finished' phase.")

    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "finished", round_id: roundId})

    case set_round_phase(stageId, roundId, "finished") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'finished'.")
        move_game_state(stageId)

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'finished' phase.")
        :exit
    end
  end

  defp handle_finished_phase(stageId, roundId) do
    Logger.debug("Stage: #{stageId}")
    Logger.debug("Live round (#{roundId}) has finished.")
    stage = "stage:" <> roundId



    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    time = extract_phase_time(stageId, "feedback")
    Logger.debug("Round finished. Sleeping for #{time} mills.")
    Process.sleep(time)

    StageMemoryService.delete_round_data(stageId)


    new_round_id = init_live_round()
    Logger.debug("Starting a new round with round ID: #{new_round_id}.")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{
      phase: "finish",
      round_id: new_round_id,
      prev_round_id: roundId
    })

    case set_round_phase(stageId, new_round_id, "preparing") do
      true ->
        Logger.debug("Successfully updated round (#{new_round_id}) phase to 'preparing'.")
        move_game_state(stageId)

      false ->
        Logger.error("Failed to update new round (#{new_round_id}) to 'preparing' phase.")
        :exit
    end
  end

  def move_game_state(stageId) do
    case StageMemoryService.read_live_round(stageId) do
      state ->
        phase = Map.get(state, :phase)
        roundId = Map.get(state, :roundId)
        Logger.debug("Stage: #{stageId}")
        Logger.debug("Phase: #{phase}. Round ID: #{roundId} Moving game state.")

        cond do
          phase == "preparing" -> handle_preparing_phase(stageId, roundId)
          phase == "performing" -> handle_performing_phase(stageId, roundId)
          phase == "feedbacks" -> handle_feedback_phase(stageId, roundId)
          phase == "finished" -> handle_finished_phase(stageId, roundId)
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
        Logger.debug(
          "Successfully inserted/updated round (#{roundId}) to phase: '#{phase}'. message: #{message}"
        )

        true

      {:error, reason} ->
        Logger.error(
          "Failed to insert/update round (#{roundId}) to phase: '#{phase}'. reason: #{reason}"
        )

        false
    end
  end

  defp init_live_round() do
    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    roundId = Ecto.UUID.generate()
    Logger.debug("Generated new round ID: #{roundId}.")
    roundId
  end

  def start(stageId) do
    roundId = init_live_round()
    Logger.info("starting state machine: #{stageId}")
    Logger.info("generated round id: #{roundId}")

    # case. start fresh round
    StageMemoryService.delete_round_data(stageId)

    case set_round_phase(stageId, roundId, "preparing") do
      true ->
        Logger.debug("Starting state machine for round (#{roundId}).")
        move_game_state(stageId)

      false ->
        Logger.error("Failed to initialize round (#{roundId}) in 'preparing' phase.")
        :exit
    end
  end
end
