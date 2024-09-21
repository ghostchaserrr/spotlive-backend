defmodule Spotlive.UserMemoryService do
  require Logger

  def store_otp(username, otp) do
    Logger.info("Storing OTP for Username: #{username}")

    case Redix.command(:redix, ["SET", username, otp]) do
      {:ok, "OK"} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to store OTP for #{username}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def retrieve_otp(username, round_id) do
    key = "#{username}"

    case Redix.command(:redix, ["GET", username]) do
      {:ok, otp} when is_binary(otp) ->
        {:ok, otp}

      {:ok, nil} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to retrieve OTP for #{username}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
