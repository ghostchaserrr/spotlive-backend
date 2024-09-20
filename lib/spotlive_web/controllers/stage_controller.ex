defmodule SpotliveWeb.StageController do
  use SpotliveWeb, :controller
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserDatabaseService
  alias Spotlive.StageMemoryService
  alias SpotliveWeb.CommonHelper
  require Logger

  def stages(conn, params) do
    stages = StageMemoryService.read_live_stages()

    conn
    |> put_status(200)
    |> json(stages)
  end

  def stage(conn, params) do
    stageId = Map.get(params, "stageId", nil)
    phase = StageMemoryService.read_live_round(stageId)
    roundId = Map.get(phase, :roundId)

    seats = StageMemoryService.read_seats(roundId)
    users = StageMemoryService.read_users(roundId)
    performer = StageMemoryService.read_performer(roundId)

    # case. create mapping
    users = CommonHelper.construct_users_map(users)
    seats = CommonHelper.construct_seats_map(seats)

    conn
    |> put_status(200)
    |> json(%{
      "seats" => seats,
      "stageId" => stageId,
      "phase" => phase,
      "users" => users,
      "performer" => performer
    })
  end
end
