defmodule SpotliveWeb.StageStateMachine do
  alias  SpotliveWeb.CommonHelper
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

  defp handlePreparingPhase(roundId) do
    id = get_stage_id()

    Logger.debug("current stage id (#{id})")
    Logger.debug("Live round (#{roundId}) is now in 'preparing' phase.")

    # Guests prepare for the show start
    Logger.debug("Guests are preparing for the show. Sleeping for 5 seconds.")
    Process.sleep(60_000)


    # topic.
    stage = "stage:" <> roundId

    # phase preparing
    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "preparing", round_id: roundId})

    Logger.debug("Stage ID: #{stage}. Preparing phase ending, transitioning to 'performing' phase.")
    Logger.debug("---------------------------------------------------------------------------------")

    case setRoundPhase(roundId, "performing") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'performing'.")
        moveGameState()

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'performing' phase.")
        :exit
    end
  end

  defp handlePerformingPhase(roundId) do
    Logger.debug("Live round (#{roundId}) is now in 'performing' phase.")

    # Stage performer has 30 seconds to say a joke (mocked as 5 seconds)
    Logger.debug("Performer is on stage. Sleeping for 5 seconds.")
    Process.sleep(5000)

    stage = "stage:" <> roundId
    Logger.debug("Stage ID: #{stage}. performing phase ending, transitioning to 'feedbacks' phase.")
    Logger.debug("---------------------------------------------------------------------------------")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "feedbacks", round_id: roundId})

    case setRoundPhase(roundId, "feedbacks") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'feedbacks'.")
        moveGameState()

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'feedbacks' phase.")
        :exit
    end
  end

  defp handleFeedbackPhase(roundId) do
    Logger.debug("Live round (#{roundId}) is now in 'feedbacks' phase.")

    # Feedback phase lasts 30 seconds (mocked as 5 seconds)
    Logger.debug("Audience providing feedback. Sleeping for 5 seconds.")
    Process.sleep(5000)

    stage = "stage:" <> roundId
    Logger.debug("Stage ID: #{stage}. Feedback phase ending, transitioning to 'finished' phase.")
    Logger.debug("---------------------------------------------------------------------------------")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{phase: "finished", round_id: roundId})

    case setRoundPhase(roundId, "finished") do
      true ->
        Logger.debug("Successfully updated round (#{roundId}) phase to 'finished'.")
        moveGameState()

      false ->
        Logger.error("Failed to update round (#{roundId}) to 'finished' phase.")
        :exit
    end
  end

  defp handleRoundFinishedPhase(roundId) do
    Logger.debug("Live round (#{roundId}) has finished.")
    stage = "stage:" <> roundId
    Logger.debug("Stage ID: #{stage}. Clearing live round data from ETS.")

    # Clear live round data
    :ets.delete(:seat_lookup, get_stage_id())

    # Wait 2 seconds before starting a new round
    Logger.debug("---------------------------------------------------------------------------------")
    Logger.debug("Waiting for 2 seconds before starting a new round.")

    Process.sleep(5000)

    # Continue loop with a new round
    new_round_id = initNewRound()
    Logger.debug("Starting a new round with round ID: #{new_round_id}.")

    SpotliveWeb.Endpoint.broadcast(stage, "phase_update", %{
      phase: "finish",
      round_id: new_round_id,
      prev_round_id: roundId
    })

    case setRoundPhase(new_round_id, "preparing") do
      true ->
        Logger.debug("Successfully updated round (#{new_round_id}) phase to 'preparing'.")
        moveGameState()

      false ->
        Logger.error("Failed to update new round (#{new_round_id}) to 'preparing' phase.")
        :exit
    end
  end

  def moveGameState do
    result = :ets.lookup(:round_lookup, get_stage_id())

    case result do
      [] ->
        Logger.error("No live round data found for the key 'live-round'.")

      [{_liveRoundKey, roundId, phase}] ->
        Logger.debug("Current round: #{roundId}, Phase: #{phase}. Moving game state.")

        cond do
          phase == "preparing" -> handlePreparingPhase(roundId)
          phase == "performing" -> handlePerformingPhase(roundId)
          phase == "feedbacks" -> handleFeedbackPhase(roundId)
          phase == "finished" -> handleRoundFinishedPhase(roundId)
        end
    end
  end

  defp setRoundPhase(roundId, phase) do
    round_tuple = {get_stage_id(), roundId, phase}
    result = :ets.insert(:round_lookup, round_tuple)

    if result do
      Logger.debug("Successfully inserted/updated round (#{roundId}) to phase: '#{phase}'.")
      true
    else
      Logger.error("Failed to insert/update round (#{roundId}) to phase: '#{phase}'.")
      false
    end
  end

  defp initNewRound() do
    Logger.debug("---------------------------------------------------------------------------------")
    roundId = Ecto.UUID.generate()
    Logger.debug("Generated new round ID: #{roundId}.")
    roundId
  end

  def init() do
    roundId = initNewRound()
    Logger.debug("initing current stage")

    case setRoundPhase(roundId, "preparing") do
      true ->
        Logger.debug("Starting state machine for round (#{roundId}).")
        moveGameState()

      false ->
        Logger.error("Failed to initialize round (#{roundId}) in 'preparing' phase.")
        :exit
    end
  end

end
