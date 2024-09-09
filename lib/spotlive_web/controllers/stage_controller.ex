defmodule SpotliveWeb.StageController do
    use SpotliveWeb, :controller
    alias SpotliveWeb.JWTHelper
    alias Spotlive.UserService
    require Logger

    def stage(conn, params) do

      stage_id = Map.get(params, "stageId", nil)
      viewers = :ets.tab2list(:user_stage_lookup)

      # IO.inspect("views:")
      IO.inspect(viewers)
    
      # Filter viewers by the stage_id, which is the first item in the tuple
      viewers = Enum.filter(viewers, fn {viewer_stage_id, _, _} -> 
        viewer_stage_id == stage_id 
      end)

      # case. reconstruct tuple as array of maps
      viewers = Enum.map(viewers, fn {stageId, userId, username} ->
        %{
          :stageId => stageId,
          :userId => userId,
          :username => username
        }
      end)
    
      # Now `filtered_viewers` contains only the entries where the stage_id matches
      Logger.debug("Filtered viewers for stage #{stage_id}:")
      Logger.debug(inspect(viewers))
    
      conn
      |> put_status(200)
      |> json(%{"viewers" => viewers})
    end
  
    def stages(conn, _params) do
      session = conn.assigns[:session]
      stages = :ets.tab2list(:round_lookup)
      stages = Enum.map(stages, fn {stage_id, round_id, phase} ->
        %{
          stage_id: stage_id,
          round_id: round_id,
          phase: phase
        }
      end)
      Logger.debug("current live stages")
      Logger.debug(inspect(stages))
      conn
      |> put_status(200)
      |> json(%{"stages" => stages})
    end

  end