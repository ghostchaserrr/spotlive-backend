defmodule Spotlive.StageMemoryService do
  require Logger

  @redis_key_prefix "stage:"

  def store_connected_user(stageId, userId, username) do
    Logger.info(
      "Storing connected user. Stage ID: #{stageId}, User ID: #{userId}, Username: #{username}"
    )

    key = "#{@redis_key_prefix}#{stageId}:users"
    Redix.command!(:redix, ["HSET", key, userId, username])
  end

  def store_taken_seat(stageId, seatIdx, userId) do
    Logger.info(
      "Storing taken seat. Stage ID: #{stageId}, Seat Index: #{seatIdx}, User ID: #{userId}"
    )

    key = "#{@redis_key_prefix}#{stageId}:seats"
    Redix.command!(:redix, ["HSET", key, seatIdx, userId])
  end

  def delete_connected_user(stageId, userId) do
    Logger.info("Deleting connected user. Stage ID: #{stageId}, User ID: #{userId}")

    key = "#{@redis_key_prefix}#{stageId}:users"

    case Redix.command(:redix, ["HDEL", key, userId]) do
      {:ok, _deleted_count} ->
        Logger.info(
          "Successfully deleted connected user with ID: #{userId} from Stage ID: #{stageId}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to delete connected user with ID: #{userId} from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def performer(stageId) do
    performers = :ets.tab2list(:performer_lookup)

    performers =
      Enum.filter(performers, fn {currentStageId, _, _} ->
        currentStageId == stageId
      end)

    IO.inspect(performers)

    performers =
      Enum.map(performers, fn {stageId, userId, username} ->
        %{
          :stageId => stageId,
          :userId => userId,
          :username => username
        }
      end)

    IO.inspect(performers)
    List.first(performers)
  end

  def store_stage_performer(stageId, userId, username) do
    Logger.info("Storing stage performer. Stage ID: #{stageId}, User ID: #{userId}, Username: #{username}")

    key = "#{@redis_key_prefix}#{stageId}:performer"
    case Redix.command(:redix, ["HSET", key, userId, username]) do
      {:ok, _response} ->
        Logger.info("Successfully stored performer with User ID: #{userId} for Stage ID: #{stageId}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to store performer with User ID: #{userId} for Stage ID: #{stageId}. Reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def has_stage_performer(stageId) do
    case :ets.lookup(:performer_lookup, stageId) do
      [] -> false
      _ -> true
    end
  end

  def delete_taken_seat(stageId, seatIdx, userId) do
    Logger.info("Deleting seat user. Stage ID: #{stageId}, User ID: #{userId}")

    key = "#{@redis_key_prefix}#{stageId}:seats"
    
    case Redix.command(:redix, ["HDEL", key, userId]) do
      {:ok, _deleted_count} ->
        Logger.info(
          "Successfully deleted seat, user with ID: #{userId} from Stage ID: #{stageId}"
        )
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to delete seat user with ID: #{userId} from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def users(stageId) do
    users = :ets.tab2list(:user_lookup)

    # case. filter out current stage users
    Enum.filter(users, fn {currentStageIdx, _, _} ->
      currentStageIdx == stageId
    end)

    users =
      Enum.map(users, fn {stageId, userId, username} ->
        %{
          :stageId => stageId,
          :userId => userId,
          :username => username
        }
      end)
  end

  def rounds do
    rounds = :ets.tab2list(:round_lookup)

    rounds =
      Enum.map(rounds, fn {stageId, roundId, phase} ->
        %{
          :stageId => stageId,
          :roundId => roundId,
          :phase => phase
        }
      end)
  end

  def seatsByStageAndUser(stageId, userId) do
    seats = :ets.tab2list(:seat_lookup)

    seats =
      Enum.filter(seats, fn {currentStageIdx, _, currentUserId} ->
        currentStageIdx == stageId and currentUserId == userId
      end)

    Enum.map(seats, fn {stageId, seatId, userId} ->
      %{
        :stageId => stageId,
        :seatId => seatId,
        :userId => userId
      }
    end)
  end

  def seats(stageId) do
    seats = :ets.tab2list(:seat_lookup)

    seats =
      Enum.filter(seats, fn {currentStageIdx, _, _} ->
        currentStageIdx == stageId
      end)

    Enum.map(seats, fn {stageId, seatId, userId} ->
      %{
        :stageId => stageId,
        :seatId => seatId,
        :userId => userId
      }
    end)
  end

  def viewers(stageId) do
    viewers = :ets.tab2list(:user_stage_lookup)

    # Filter viewers by the stage_id, which is the first item in the tuple
    viewers =
      Enum.filter(viewers, fn {currentStageIdx, _, _} ->
        currentStageIdx == stageId
      end)

    # case. reconstruct tuple as array of maps
    Enum.map(viewers, fn {stageId, userId, username} ->
      %{
        :stageId => stageId,
        :userId => userId,
        :username => username
      }
    end)
  end
end
