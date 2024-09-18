defmodule Spotlive.StageMemoryService do
  require Logger

  @redis_key_prefix "stage:"
  @redis_round_key_prefix "round:"
  @redis_stage_config_prefix "config:"

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

    scan_live_stages_keys(0, key, fn keys ->
      keys
    end)
  end

  def scan_live_stages_keys(cursor, key, func) do
    command = ["SCAN", cursor, "MATCH", key]
    {:ok, [new_cursor, keys]} = Redix.command(:redix, command)

    case new_cursor do
      # exit case
      "0" ->
        func.(keys)

      _ ->
        func.(keys) ++ scan_live_stages_keys(new_cursor, key, func)
    end
  end

  def read_live_round_phase(stageId) do
    case read_live_round(stageId) do
      state ->
        Map.get(state, :phase)

      {:error, reason} ->
        Logger.error(
          "Failed to read live phase from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def get_config(stageId) do
    key = "#{@redis_stage_config_prefix}#{stageId}"
    Logger.info(key)

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        nil

      {:ok, configs} ->
        Logger.info("configs: #{inspect(configs)}")

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

    Logger.info("preparing: #{preparing}")
    Logger.info("performing: #{performing}")
    Logger.info("feedback: #{feedback}")
    Logger.info("finish: #{finish}")

    key = "#{@redis_stage_config_prefix}#{stageId}"
    Logger.info(key)

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
      finish
    ])

    Logger.info("config inserted #{stageId} #{inspect(config)}")
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
          "Failed to read live round from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
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

  def store_connected_user(stageId, userId, username) do
    Logger.info(
      "Storing connected user. Stage ID: #{stageId}, User ID: #{userId}, Username: #{username}"
    )

    key = "#{@redis_key_prefix}#{stageId}:users"
    Redix.command!(:redix, ["HSET", key, userId, username])
  end

  def read_seats(stageId) do
    key = "#{@redis_key_prefix}#{stageId}:seats"

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        []

      {:ok, users} ->
        Enum.chunk_every(users, 2)
        |> Enum.map(fn [seatIdx, userId] ->
          %{:seatIdx => String.to_integer(seatIdx), :userId => String.to_integer(userId)}
        end)

      {:error, reason} ->
        Logger.error(
          "Failed to read performer from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def read_users(stageId) do
    key = "#{@redis_key_prefix}#{stageId}:users"
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
          "Failed to read performer from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
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

  def store_taken_seat(stageId, seatIdx, userId) do
    Logger.info(
      "Storing taken seat. Stage ID: #{stageId}, Seat Index: #{seatIdx}, User ID: #{userId}"
    )

    key = "#{@redis_key_prefix}#{stageId}:seats"
    Redix.command!(:redix, ["HSET", key, seatIdx, userId])
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

  def delete_connected_user(stageId, userId) do
    Logger.info("Deleting connected user. Stage ID: #{stageId}, User ID: #{userId}")

    key = "#{@redis_key_prefix}#{stageId}:users"

    case Redix.command(:redix, ["HDEL", key, userId]) do
      {:ok, _deleted_count} ->
        Logger.info(
          "Successfully deleted connected user with ID: #{userId} from Stage ID: #{stageId}"
        )

        true

      {:error, reason} ->
        Logger.error(
          "Failed to delete connected user with ID: #{userId} from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def read_performer(stageId) do
    key = "#{@redis_key_prefix}#{stageId}:performer"

    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        nil

      {:ok, performers} ->
        Enum.chunk_every(performers, 2)
        |> Enum.map(fn [userId, username] ->
          %{id: String.to_integer(userId), username: username}
        end)
        |> List.first()

      {:error, reason} ->
        Logger.error(
          "Failed to read performer from Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def store_stage_performer(stageId, userId, username) do
    Logger.info(
      "Storing stage performer. Stage ID: #{stageId}, User ID: #{userId}, Username: #{username}"
    )

    key = "#{@redis_key_prefix}#{stageId}:performer"

    case Redix.command(:redix, ["HSET", key, userId, username]) do
      {:ok, _response} ->
        Logger.info(
          "Successfully stored performer with User ID: #{userId} for Stage ID: #{stageId}"
        )

        true

      {:error, reason} ->
        Logger.error(
          "Failed to store performer with User ID: #{userId} for Stage ID: #{stageId}. Reason: #{inspect(reason)}"
        )

        false
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
end
