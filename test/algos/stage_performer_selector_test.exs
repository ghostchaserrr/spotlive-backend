defmodule Spotlive.Algos.StagePerformerSelectorTest do
  use ExUnit.Case
  alias  Spotlive.Algos.StagePerformerSelector
  require Logger

  test "case. should select performer in case players are in a round" do
    # Call the function
    ids = StagePerformerSelector.generate_random_user_ids(5)
    IO.inspect(ids)
    roundId = Ecto.UUID.generate()

    payload = StagePerformerSelector.pickPerformer(roundId, ids)

    IO.inspect(payload)

    
  end
end
