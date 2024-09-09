defmodule SpotliveWeb.Plugs.Auth do
    import Plug.Conn
    use SpotliveWeb, :controller
    alias SpotliveWeb.Router.Helpers
    alias Spotlive.UserDatabaseService
    alias SpotliveWeb.JWTHelper
    require Logger

    def init(default), do: default
    def call(conn, _opts) do
      case get_req_header(conn, "authorization") do
        [token] ->
          case JWTHelper.verify(token) do
            {:ok, %{"user_id" => user_id}} ->
              result = :ets.lookup(:session_lookup, token)
              case result do
                [] ->
                  Logger.debug("fresh: #{inspect(token)}")
                  user = UserDatabaseService.get_user_by_user_id(user_id)
                  :ets.insert(:session_lookup, {token, user.id, user.username})
                  conn
                  |> assign(:session, %{:id => user.id, :username => user.username})
    
                [{^token, user_id, username}] -> # Adjusted pattern to include token
                  Logger.debug("cache: #{inspect(token)}")
                  conn
                  |> assign(:session, %{:id => user_id, :username => username})
              end
    
            {:error, reason} ->
              Logger.error(reason)
              conn
              |> put_status(:unauthorized)
              |> json(%{"error" => "Authentication failed"})
              |> halt()
          end
    
        _ -> 
          conn
          |> put_status(:unauthorized)
          |> json(%{"error" => "Authentication failed"})
          |> halt()
      end
    end
  end