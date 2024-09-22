defmodule Spotlive.ReactionsManager do
  @reactions_mappings %{
    "👏" => 0,
    "😂" => 0,
    "❤️" => 0,
    "😮" => 0,
    "🤔" => 0,
    "👍" => 0,
    "😕" => 0,
    "👎" => 1,
    "🎉" => 0,
    "💡" => 0,
    "😢" => 1,
    "😠" => 1,
    "😴" => 1,
    "🤯" => 0,
    "🔥" => 1
  }
  def get_reaction_index(emoji) do
    case Map.get(@reactions_mappings, emoji) do
      nil -> {:error, :invalid_emoji}
      value -> {:ok, value}
    end
  end
end
