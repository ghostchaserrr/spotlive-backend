defmodule Spotlive.ContentMemoryService do
  require Logger

  @redis_key_prefix "content:"

  def store_content_text(roundId, userId, text) do
    key = "#{@redis_key_prefix}#{roundId}"

    case Redix.command(:redix, ["HSET", key, userId, text]) do
      {:ok, _} ->
        Logger.warn("success: user input stored #{text}")
        # Redis returned an ok, meaning the data was written or updated successfully
        :success

      {:error, reason} ->
        # Redis returned an error, you can handle it here
        Logger.error("error: #{reason}")
        :error
    end
  end
end
