defmodule SpotliveWeb.StageController do
  use SpotliveWeb, :controller
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserDatabaseService
  alias Spotlive.StageMemoryService
  require Logger

  def stage(conn, params) do
    stageId = "stage:" <> Map.get(params, "stageId", nil)

    # case. load viewers, seats, users
    viewers = StageMemoryService.viewers(stageId)
    seats = StageMemoryService.seats(stageId)
    users = StageMemoryService.users(stageId)
    performer = StageMemoryService.performer(stageId)

    conn
    |> put_status(200)
    |> json(%{"viewers" => viewers, "seats" => seats, "stageId" => stageId, "users" => users, "performer" => performer})
  end

  def stages(conn, _params) do
    session = conn.assigns[:session]
    rounds = StageMemoryService.rounds()
    conn
    |> put_status(200)
    |> json(%{"rounds" => rounds})
  end
end
