defmodule SpotliveWeb.StateMachine do
  def generate_round(stageId) do
    # case. prepare new ets table

    log_info("Live round start received for stage (#{stageId})")
    :ets.insert(:stage_lookup, {:stage_id, stageId})
    Task.start_link(fn -> init() end)
  end

  def get_stage_id do
    case :ets.lookup(:stage_lookup, :stage_id) do
      [{:stage_id, stageId}] -> stageId
      [] -> nil
    end
  end

  defp handlePreparingPhase(roundId) do
    id = get_stage_id()

    log_info("current stage id (#{id})")
    log_info("Live round (#{roundId}) is now in 'preparing' phase.")

    # Guests prepare for the show start
    log_info("Guests are preparing for the show. Sleeping for 5 seconds.")
    Process.sleep(30_000)

    # topic.
    stage = "stage:" <> roundId

    # phase preparing
    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "preparing", round_id: roundId})

    log_info("Stage ID: #{stage}. Preparing phase ending, transitioning to 'speaking' phase.")

    case updateRoundPhase(roundId, "speaking") do
      true ->
        log_info("Successfully updated round (#{roundId}) phase to 'speaking'.")
        moveGameState()

      false ->
        log_error("Failed to update round (#{roundId}) to 'speaking' phase.")
        :exit
    end
  end

  defp handleSpeakingPhase(roundId) do
    log_info("Live round (#{roundId}) is now in 'speaking' phase.")

    # Stage performer has 30 seconds to say a joke (mocked as 5 seconds)
    log_info("Performer is on stage. Sleeping for 5 seconds.")
    Process.sleep(30_000)

    stage = "stage:" <> roundId
    log_info("Stage ID: #{stage}. Speaking phase ending, transitioning to 'feedbacks' phase.")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "speaking", round_id: roundId})

    case updateRoundPhase(roundId, "speaking") do
      true ->
        log_info("Successfully updated round (#{roundId}) phase to 'feedbacks'.")
        moveGameState()

      false ->
        log_error("Failed to update round (#{roundId}) to 'feedbacks' phase.")
        :exit
    end
  end

  defp handleFeedbackPhase(roundId) do
    log_info("Live round (#{roundId}) is now in 'feedbacks' phase.")

    # Feedback phase lasts 30 seconds (mocked as 5 seconds)
    log_info("Audience providing feedback. Sleeping for 5 seconds.")
    Process.sleep(30_000)

    stage = "stage:" <> roundId
    log_info("Stage ID: #{stage}. Feedback phase ending, transitioning to 'finished' phase.")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "finished", round_id: roundId})

    case updateRoundPhase(roundId, "finished") do
      true ->
        log_info("Successfully updated round (#{roundId}) phase to 'finished'.")
        moveGameState()

      false ->
        log_error("Failed to update round (#{roundId}) to 'finished' phase.")
        :exit
    end
  end

  defp handleRoundFinishedPhase(roundId) do
    log_info("Live round (#{roundId}) has finished.")
    stage = "stage:" <> roundId
    log_info("Stage ID: #{stage}. Clearing live round data from ETS.")

    # Clear live round data
    :ets.delete(:seat_lookup, get_stage_id())

    # Wait 2 seconds before starting a new round
    log_info("Waiting for 2 seconds before starting a new round.")
    Process.sleep(30_000)

    # Continue loop with a new round
    new_round_id = initNewRound()
    log_info("Starting a new round with round ID: #{new_round_id}.")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{
      phase: "finish",
      round_id: new_round_id,
      prev_round_id: roundId
    })

    case updateRoundPhase(new_round_id, "preparing") do
      true ->
        log_info("Successfully updated round (#{new_round_id}) phase to 'preparing'.")
        moveGameState()

      false ->
        log_error("Failed to update new round (#{new_round_id}) to 'preparing' phase.")
        :exit
    end
  end

  def moveGameState do
    result = :ets.lookup(:round_lookup, get_stage_id())

    case result do
      [] ->
        log_error("No live round data found for the key 'live-round'.")

      [{_liveRoundKey, roundId, phase}] ->
        log_info("Current round: #{roundId}, Phase: #{phase}. Moving game state.")

        cond do
          phase == "preparing" -> handlePreparingPhase(roundId)
          phase == "speaking" -> handleSpeakingPhase(roundId)
          phase == "feedbacks" -> handleFeedbackPhase(roundId)
          phase == "finished" -> handleRoundFinishedPhase(roundId)
        end
    end
  end

  defp updateRoundPhase(roundId, phase) do
    round_tuple = {get_stage_id(), roundId, phase}
    result = :ets.insert(:round_lookup, round_tuple)

    if result do
      log_info("Successfully inserted/updated round (#{roundId}) to phase: '#{phase}'.")
      true
    else
      log_error("Failed to insert/update round (#{roundId}) to phase: '#{phase}'.")
      false
    end
  end

  defp initNewRound() do
    roundId = Ecto.UUID.generate()
    log_info("Generated new round ID: #{roundId}.")
    roundId
  end

  def init() do
    roundId = initNewRound()
    log_info("initing current stage")

    case updateRoundPhase(roundId, "preparing") do
      true ->
        log_info("Starting state machine for round (#{roundId}).")
        moveGameState()

      false ->
        log_error("Failed to initialize round (#{roundId}) in 'preparing' phase.")
        :exit
    end
  end

  # Helper function for logging informational messages
  defp log_info(message) do
    IO.puts("[INFO] #{message}")
  end

  # Helper function for logging error messages
  defp log_error(message) do
    IO.puts("[ERROR] #{message}")
  end
end
