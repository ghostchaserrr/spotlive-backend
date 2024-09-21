defmodule Spotlive.StageMemoryService do
  require Logger

  @redis_key_prefix "stage:"
  @redis_performer_prefix "performer:"
  @redis_seats_prefix "seats:"
  @redis_user_seats_prefix "user-seats:"
  @redis_users_prefix "users:"
  @redis_round_key_prefix "round:"
  @redis_stage_config_prefix "config:"

  def read_stage_userIds(roundId) do
    key = "#{@redis_users_prefix}#{roundId}"

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        []

      {:ok, mappings} ->
        Enum.chunk_every(mappings, 2)
        |> Enum.map(fn [userId, seatIdx] ->
          String.to_integer(userId)
        end)

      {:error, reason} ->
        Logger.error(
          "Failed to read live round from Round ID: #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def read_user_seats(roundId) do
    key = "#{@redis_user_seats_prefix}:#{roundId}"

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        []

      {:ok, mappings} ->
        Enum.chunk_every(mappings, 2)
        |> Enum.map(fn [userId, seatIdx] ->
          %{:userId => String.to_integer(userId), :seatIdx => seatIdx}
        end)

      {:error, reason} ->
        Logger.error(
          "Failed to read live round from Round ID: #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def read_user_seat(roundId, userId) do
    key = "#{@redis_user_seats_prefix}#{roundId}"
    command = ["HGET", key, userId]

    Logger.info("Attempting to retrieve seat for user #{userId} in round #{roundId}")

    case Redix.command(:redix, command) do
      {:ok, nil} ->
        # Handle case where the user doesn't have a seat (nil response)
        Logger.warn("User #{userId} has no seat assigned in round #{roundId}")
        {:ok, :empty}

      {:ok, ""} ->
        # Handle case where Redis returns an empty string
        Logger.warn("User #{userId} has no seat assigned (empty string) in round #{roundId}")
        {:ok, :empty}

      {:ok, seatIdx} when is_binary(seatIdx) ->
        # Successfully retrieved seat index and convert to integer
        Logger.debug("User #{userId} is currently seated at index #{seatIdx} in round #{roundId}")
        {:ok, String.to_integer(seatIdx)}

      {:error, reason} ->
        # Handle any Redis error
        Logger.error(
          "Failed to retrieve seat for user #{userId} in round #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def take_seat(roundId, seatIdx, userId) do
    userSeatMappingKey = "#{@redis_user_seats_prefix}#{roundId}"
    seatUserMappingKey = "#{@redis_seats_prefix}#{roundId}"

    # Prepare Redis commands to map user to seat and seat to user
    userSeatMappingCommand = ["HSET", userSeatMappingKey, userId, seatIdx]
    seatUserMappingCommand = ["HSET", seatUserMappingKey, seatIdx, userId]

    Logger.info("Attempting to assign seat #{seatIdx} to user #{userId} in round #{roundId}")

    # Execute Redis pipeline for both HSET commands
    case Redix.pipeline(:redix, [userSeatMappingCommand, seatUserMappingCommand]) do
      {:ok, responses} ->
        Logger.info("Successfully assigned seat #{seatIdx} to user #{userId} in round #{roundId}")

        # Convert responses into a map of keys and their respective responses
        keys = [userSeatMappingKey, seatUserMappingKey]

        Enum.zip(keys, responses)
        |> Enum.into(%{})

      {:error, reason} ->
        Logger.error(
          "Failed to assign seat #{seatIdx} to user #{userId} in round #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def read_live_stages() do
    keys = read_live_stages_keys()
    commands = Enum.map(keys, fn key -> ["HGETALL", key] end)

    # Execute commands in parallel
    {:ok, responses} = Redix.pipeline(:redix, commands)

    # Convert responses into a map of keys and their respective hash data
    Enum.zip(keys, responses)
    |> Enum.into(%{})
  end

  def read_live_stages_keys do
    key = "#{@redis_round_key_prefix}*"

    scan_keys(0, key, fn keys ->
      keys
    end)
  end

  def scan_keys(cursor, key, func) do
    command = ["SCAN", cursor, "MATCH", key]
    {:ok, [new_cursor, keys]} = Redix.command(:redix, command)

    case new_cursor do
      # exit case
      "0" ->
        func.(keys)

      _ ->
        func.(keys) ++ scan_keys(new_cursor, key, func)
    end
  end

  def read_live_round_phase(stageId) do
    case read_live_round(stageId) do
      state ->
        Map.get(state, :phase)

      {:error, reason} ->
        Logger.error(
          "Failed to read live phase from Round ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def get_config(stageId) do
    key = "#{@redis_stage_config_prefix}#{stageId}"
    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        nil

      {:ok, configs} ->
        map =
          configs
          |> Enum.chunk_every(2)
          |> Enum.into(%{}, fn [phase, duration] -> {phase, String.to_integer(duration)} end)

      {:error, reason} ->
        Logger.error("failed to load configs: Reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def init_config(stageId, config) do
    preparing = Map.get(config, :preparing)
    performing = Map.get(config, :performing)
    feedback = Map.get(config, :feedback)
    finish = Map.get(config, :finish)
    seating = Map.get(config, :seating)
    key = "#{@redis_stage_config_prefix}#{stageId}"
    Redix.command(:redix, [
      "HSET",
      key,
      "preparing",
      preparing,
      "performing",
      performing,
      "feedback",
      feedback,
      "finish",
      finish,
      "seating",
      seating
    ])
  end

  def read_live_round(stageId) do
    key = "#{@redis_round_key_prefix}#{stageId}"

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        nil

      {:ok, rounds} ->
        Enum.chunk_every(rounds, 2)
        |> Enum.map(fn [roundId, phase] ->
          %{:roundId => roundId, :phase => phase}
        end)
        |> List.first()

      {:error, reason} ->
        Logger.error(
          "Failed to read live round from Round ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def store_or_update_live_round(stageId, roundId, phase) do
    key = "#{@redis_round_key_prefix}#{stageId}"

    case Redix.command(:redix, ["HSET", key, roundId, phase]) do
      {:ok, _} ->
        # Redis returned an ok, meaning the data was written or updated successfully
        {:ok, "Round ID field updated successfully"}

      {:error, reason} ->
        # Redis returned an error, you can handle it here
        {:error, "Failed to update round ID field: #{reason}"}
    end
  end

  def delete_round_data(stageId) do
    key = "#{@redis_round_key_prefix}#{stageId}"

    case Redix.command(:redix, ["DEL", key]) do
      {:ok, deleted_count} when deleted_count > 0 ->
        {:ok, "Round data deleted successfully"}

      {:ok, 0} ->
        {:error, "No round data found for the given stage"}

      {:error, reason} ->
        {:error, "Failed to delete round data: #{reason}"}
    end
  end

  def store_connected_user(roundId, userId, username) do
    Logger.info(
      "Storing connected user. Round ID: #{roundId}, User ID: #{userId}, Username: #{username}"
    )

    key = "#{@redis_users_prefix}#{roundId}"
    Redix.command!(:redix, ["HSET", key, userId, username])
  end

  def read_seats(roundId) do
    key = "#{@redis_seats_prefix}#{roundId}"

    Logger.info("Attempting to read seats for Round ID: #{roundId}")

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        Logger.info("No seats found for Round ID: #{roundId}")
        []

      {:ok, users} ->
        Logger.info("Successfully retrieved seats for Round ID: #{roundId}. Parsing seat data...")

        Enum.chunk_every(users, 2)
        |> Enum.map(fn [seatIdx, userId] ->
          %{:seatIdx => String.to_integer(seatIdx), :userId => String.to_integer(userId)}
        end)

      {:error, reason} ->
        Logger.error("Failed to read seats from Round ID: #{roundId}. Reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def read_users(roundId) do
    key = "#{@redis_users_prefix}#{roundId}"
    Logger.warn("users key: #{key}")

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        []

      {:ok, users} ->
        Enum.chunk_every(users, 2)
        |> Enum.map(fn [userId, username] ->
          %{id: String.to_integer(userId), username: username}
        end)

      {:error, reason} ->
        Logger.error(
          "Failed to read performer from Round ID: #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def read_seat_availability(seatIdx, roundId) do
    # Compose the Redis key for the seats in the round
    key = "#{@redis_seats_prefix}#{roundId}"

    # Attempt to fetch the user ID from Redis using HGET
    case Redix.command(:redix, ["HGET", key, seatIdx]) do
      {:ok, nil} ->
        # Handle case where seat is empty (no user ID found for the seat)
        Logger.warn("No user found at seat #{seatIdx} for round #{roundId}")
        :empty

      {:ok, userId} ->
        # Log the successful retrieval of the user ID
        Logger.info("User ID #{userId} found at seat #{seatIdx} for round #{roundId}")
        :reserved

      {:error, reason} ->
        # Log the error and return the error reason
        Logger.error(
          "Failed to read user at seat #{seatIdx} for round #{roundId}: #{inspect(reason)}"
        )

        :error
    end
  end

  def read_username(stageId, userId) do
    key = "#{@redis_key_prefix}#{stageId}:users"

    case Redix.command(:redix, ["HGET", key, userId]) do
      {:ok, username} ->
        username

      {:error, reason} ->
        nil
    end
  end

  def read_seat_user(stageId, seatIdx) do
    key = "#{@redis_key_prefix}#{stageId}:seats"

    case Redix.command(:redix, ["HGET", key, seatIdx]) do
      {:ok, userId} ->
        case userId do
          nil -> nil
          userId -> String.to_integer(userId)
        end

      {:error, reason} ->
        nil
    end
  end

  def store_taken_seat(roundId, seatIdx, userId) do
    Logger.info(
      "Storing taken seat. Round ID: #{roundId}, Seat Index: #{seatIdx}, User ID: #{userId}"
    )

    key = "#{@redis_seats_prefix}#{roundId}"

    case Redix.command(:redix, ["HSET", key, seatIdx, userId]) do
      {:ok, result} ->
        # Log success
        Logger.info(
          "Successfully stored seat. Round ID: #{roundId}, Seat Index: #{seatIdx}, User ID: #{userId}. Redis response: #{inspect(result)}"
        )

        {:ok, result}

      {:error, reason} ->
        # Log failure
        Logger.error(
          "Failed to store seat. Round ID: #{roundId}, Seat Index: #{seatIdx}, User ID: #{userId}. Error: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def delete_round_field(stageId, roundId) do
    key = "#{@redis_round_key_prefix}#{stageId}"

    case Redix.command(:redix, ["HDEL", key, roundId]) do
      {:ok, deleted_count} when deleted_count > 0 ->
        {:ok, "Round ID field deleted successfully"}

      {:ok, 0} ->
        {:error, "Round ID field not found"}

      {:error, reason} ->
        {:error, "Failed to delete round ID field: #{reason}"}
    end
  end

  def delete_connected_user(roundId, userId) do
    Logger.info("Deleting connected user. Round ID: #{roundId}, User ID: #{userId}")

    key = "#{@redis_users_prefix}#{roundId}"

    case Redix.command(:redix, ["HDEL", key, userId]) do
      {:ok, _deleted_count} ->
        Logger.info(
          "Successfully deleted connected user with ID: #{userId} from Round ID: #{roundId}"
        )

        true

      {:error, reason} ->
        Logger.error(
          "Failed to delete connected user with ID: #{userId} from Round ID: #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def read_performer(roundId) do
    key = "#{@redis_performer_prefix}#{roundId}"

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        # No performer found
        Logger.info("No performer found for Round ID: #{roundId}.")
        nil

      {:ok, performers} ->
        case Enum.chunk_every(performers, 2) do
          [] ->
            # In case we get an empty list after chunking
            Logger.warn("Unexpected empty performer data for Round ID: #{roundId}.")
            nil

          chunks ->
            chunks
            |> Enum.map(fn [userId, username] ->
              case Integer.parse(userId) do
                {int_user_id, _} ->
                  %{id: int_user_id, username: username}

                :error ->
                  Logger.error(
                    "Failed to parse userId: #{userId} as an integer for Round ID: #{roundId}."
                  )

                  nil
              end
            end)
            # Find the first valid performer (non-nil)
            |> Enum.find(& &1)
        end

      {:error, reason} ->
        # Log error details
        Logger.error(
          "Failed to read performer for Round ID: #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def select_performer(roundId, userId, username) do
    Logger.info(
      "Attempting to store stage performer. Round ID: #{roundId}, User ID: #{userId}, Username: #{username}"
    )

    key = "#{@redis_performer_prefix}#{roundId}"

    case Redix.command(:redix, ["HSET", key, userId, username]) do
      {:ok, response} ->
        Logger.info(
          "Successfully stored performer. Round ID: #{roundId}, User ID: #{userId}, Username: #{username}. Redis response: #{inspect(response)}"
        )

        true

      {:error, reason} ->
        Logger.error(
          "Failed to store performer. Round ID: #{roundId}, User ID: #{userId}, Username: #{username}. Error: #{inspect(reason)}"
        )

        false
    end
  end

  def delete_seat(roundId, seatIdx, userId) do
    userSeatMappingKey = "#{@redis_user_seats_prefix}#{roundId}"
    seatUserMappingKey = "#{@redis_seats_prefix}#{roundId}"

    # Prepare Redis commands to map user to seat and seat to user
    userSeatMappingCommand = ["HDEL", userSeatMappingKey, userId]
    seatUserMappingCommand = ["HDEL", seatUserMappingKey, seatIdx]

    Logger.info("Attempting to assign seat #{seatIdx} to user #{userId} in round #{roundId}")

    # Execute Redis pipeline for both HSET commands
    case Redix.pipeline(:redix, [userSeatMappingCommand, seatUserMappingCommand]) do
      {:ok, responses} ->
        Logger.info("Successfully deleted seat #{seatIdx} to user #{userId} in round #{roundId}")

        # Convert responses into a map of keys and their respective responses
        keys = [userSeatMappingKey, seatUserMappingKey]

        {:ok, keys}

      {:error, reason} ->
        Logger.error(
          "Failed to assign seat #{seatIdx} to user #{userId} in round #{roundId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}

      _ ->
        {:ok, 0}
    end
  end
end
