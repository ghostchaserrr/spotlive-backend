defmodule SpotliveWeb.StageController do
  use SpotliveWeb, :controller
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserDatabaseService
  alias Spotlive.StageMemoryService
  require Logger

  def stages(conn, params) do
    stages = StageMemoryService.read_live_stages()
    conn
    |> put_status(200)
    |> json(stages)
  end

  def stage(conn, params) do
    stageId = "stage:" <> Map.get(params, "stageId", nil)

    seats = StageMemoryService.read_seats(stageId)
    users = StageMemoryService.read_users(stageId)
    performer = StageMemoryService.read_performer(stageId)

    conn
    |> put_status(200)
    |> json(%{"seats" => seats, "stageId" => stageId, "users" => users, "performer" => performer})
  end
end
