defmodule SpotliveWeb.StageController do
  use SpotliveWeb, :controller
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserDatabaseService
  alias Spotlive.StageMemoryService
  require Logger

  def stage(conn, params) do
    stageId = "stage:" <> Map.get(params, "stageId", nil)

    seats = StageMemoryService.read_seats(stageId)
    users = StageMemoryService.read_users(stageId)
    performer = StageMemoryService.read_performer(stageId)

    conn
    |> put_status(200)
    |> json(%{"seats" => seats, "stageId" => stageId, "users" => users, "performer" => performer})
  end

  def stages(conn, _params) do
    session = conn.assigns[:session]
    rounds = StageMemoryService.rounds()
    conn
    |> put_status(200)
    |> json(%{"rounds" => rounds})
  end
end
