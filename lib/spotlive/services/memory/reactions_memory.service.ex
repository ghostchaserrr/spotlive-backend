defmodule Spotlive.ReactionsMemoryService do
  require Logger

  @redis_key_prefix "reactions:"

  def read_reactions(round_id) do
    key = "#{@redis_key_prefix}#{round_id}"

    case Redix.command(:redix, ["LRANGE", key, "0", "-1"]) do
      {:ok, reactions} ->
        Enum.map(reactions, fn reaction ->
          case String.split(reaction, ":") do
            [username, index, emoji] ->
              %{
                :username => username,
                :index => String.to_integer(index),
                :emoji => emoji
              }

            _ ->
              Logger.error("Invalid reaction format: #{reaction}")
              []
          end
          
        end)
      {:error, reason} ->
        Logger.error("Failed to read reactions: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def store_reaction(roundId, username, index, value) do
    key = "#{@redis_key_prefix}#{roundId}"
    value = "#{username}:#{index}:#{value}"

    Logger.info("Storing reaction for round: #{roundId}, user: #{username}, reaction: #{value}")

    case Redix.command(:redix, ["LPUSH", key, value]) do
      {:ok, response} ->
        Logger.info(
          "Reaction stored successfully for round: #{roundId}, user: #{username}. Redis response: #{inspect(response)}"
        )

        {:ok, "Reaction stored successfully"}

      {:error, reason} ->
        Logger.error("""
        Failed to store reaction for round: #{roundId}, user: #{username}, reaction: #{value}.
        Redis error: #{inspect(reason)}
        """)

        {:error, reason}
    end
  end
end
