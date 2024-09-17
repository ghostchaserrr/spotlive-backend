defmodule SpotliveWeb.StageStateMachine do
  alias SpotliveWeb.CommonHelper
  alias Spotlive.StageMemoryService
  require Logger

  def generate_round(stageId) do
    # case. prepare new ets table

    Logger.debug("Live round start received for stage (#{stageId})")
    :ets.insert(:stage_lookup, {:stage_id, stageId})
    Task.start_link(fn -> init() end)
  end

  def get_stage_id do
    case :ets.lookup(:stage_lookup, :stage_id) do
      [{:stage_id, stageId}] -> stageId
      [] -> nil
    end
  end

  defp handle_preparing_phase(roundId) do
    id = get_stage_id()

    Logger.debug("current stage id (#{id})")
    Logger.debug("Live round (#{roundId}) is now in 'preparing' phase.")

    # Guests prepare for the show start
    Logger.debug("Guests are preparing for the show. Sleeping for 5 seconds.")
    Process.sleep(2000)

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

    case set_round_phase(roundId, "performing") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'performing'.")
        move_game_state()

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'performing' phase.")
        :exit
    end
  end

  defp handle_performing_phase(roundId) do
    Logger.debug("Live round (#{roundId}) is now in 'performing' phase.")

    # Stage performer has 30 seconds to say a joke (mocked as 5 seconds)
    Logger.debug("Performer is on stage. Sleeping for 5 seconds.")
    Process.sleep(5000)

    stage = "stage:" <> roundId

    Logger.debug(
      "Stage ID: #{stage}. performing phase ending, transitioning to 'feedbacks' phase."
    )

    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "feedbacks", round_id: roundId})

    case set_round_phase(roundId, "feedbacks") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'feedbacks'.")
        move_game_state()

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'feedbacks' phase.")
        :exit
    end
  end

  defp handle_feedback_phase(roundId) do
    Logger.debug("Live round (#{roundId}) is now in 'feedbacks' phase.")

    # Feedback phase lasts 30 seconds (mocked as 5 seconds)
    Logger.debug("Audience providing feedback. Sleeping for 5 seconds.")
    Process.sleep(5000)

    stage = "stage:" <> roundId
    Logger.debug("Stage ID: #{stage}. Feedback phase ending, transitioning to 'finished' phase.")

    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "finished", round_id: roundId})

    case set_round_phase(roundId, "finished") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'finished'.")
        move_game_state()

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'finished' phase.")
        :exit
    end
  end

  defp handle_finished_phase(roundId) do
    Logger.debug("Live round (#{roundId}) has finished.")
    stage = "stage:" <> roundId
    Logger.debug("Stage ID: #{stage}. Clearing live round data from ETS.")

    # Wait 2 seconds before starting a new round
    Logger.debug(
      "---------------------------------------------------------------------------------"
    )

    Logger.debug("Waiting for 2 seconds before starting a new round.")

    Process.sleep(5000)

    # case. remove round
    StageMemoryService.delete_round_data(get_stage_id())

    # Continue loop with a new round
    new_round_id = init_live_round()
    Logger.debug("Starting a new round with round ID: #{new_round_id}.")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{
      phase: "finish",
      round_id: new_round_id,
      prev_round_id: roundId
    })

    case set_round_phase(new_round_id, "preparing") do
      true ->
        Logger.debug("Successfully updated round (#{new_round_id}) phase to 'preparing'.")
        move_game_state()

      false ->
        Logger.error("Failed to update new round (#{new_round_id}) to 'preparing' phase.")
        :exit
    end
  end

  def move_game_state do
    case StageMemoryService.read_live_round(get_stage_id()) do
      state ->
        phase = Map.get(state, :phase)
        roundId = Map.get(state, :roundId)
        Logger.debug("Phase: #{phase}. Round ID: #{roundId} Moving game state.")

        cond do
          phase == "preparing" -> handle_preparing_phase(roundId)
          phase == "performing" -> handle_performing_phase(roundId)
          phase == "feedbacks" -> handle_feedback_phase(roundId)
          phase == "finished" -> handle_finished_phase(roundId)
        end

      {:error, reason} ->
        :exit
    end
  end

  defp set_round_phase(roundId, phase) do
    case StageMemoryService.store_or_update_live_round(get_stage_id(), roundId, phase) do
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

  def init() do
    roundId = init_live_round()
    Logger.debug("initing current stage")

    case set_round_phase(roundId, "preparing") do
      true ->
        Logger.debug("Starting state machine for round (#{roundId}).")
        move_game_state()

      false ->
        Logger.error("Failed to initialize round (#{roundId}) in 'preparing' phase.")
        :exit
    end
  end
end
