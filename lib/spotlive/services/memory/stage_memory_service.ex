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

  def read_seats(stageId) do
    key = "#{@redis_key_prefix}#{stageId}:seats"
    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} ->
        []

      {:ok, users} ->
        Enum.chunk_every(users, 2)
        |> Enum.map(fn [seatIdx, userId] -> %{:seatIdx => String.to_integer(seatIdx), :userId => String.to_integer(userId)} end)

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
        |> Enum.map(fn [userId, username] -> %{id: String.to_integer(userId), username: username} end)

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
        |> Enum.map(fn [userId, username] -> %{id: String.to_integer(userId), username: username} end)
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

end
