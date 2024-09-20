defmodule Spotlive.Algos.StagePerformerSelector do
  require :crypto

  def generate_random_user_ids(count) when is_integer(count) and count > 0 do
    1..count
    |> Enum.map(fn _ -> :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned() end)
    |> Enum.uniq()
  end

  def pickPerformer(roundId, userIds) do
    nonce = generateNonce()

    # Take the first 3 players or generate a random seed if none
    playerSeeds =
      case userIds do
        [] ->
          [generateRandomSeed()]

        _ ->
          Enum.take(userIds, 3) |> Enum.map(&Integer.to_string/1)
      end

    # Combine the data
    data = "#{roundId}#{Enum.join(playerSeeds)}#{nonce}"

    # Generate the hash
    hash = :crypto.hash(:sha256, data)

    # Convert hash to an integer
    hashInteger = :binary.decode_unsigned(hash)

    # Determine the performer index
    performerIndex = rem(hashInteger, length(userIds))

    selectedPerformer = Enum.at(userIds, performerIndex)

    %{
      :userId => selectedPerformer,
      :nonce => nonce,
      :hash => hash,
      :roundId => roundId,
      :playerSeeds => playerSeeds,
      :hashInteger => hashInteger,
      :data => data
    }
  end

  defp generateNonce do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end

  defp generateRandomSeed do
    :crypto.strong_rand_bytes(4) |> Base.encode16()
  end
end
