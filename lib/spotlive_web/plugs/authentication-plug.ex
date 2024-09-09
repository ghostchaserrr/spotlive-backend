defmodule SpotliveWeb.Plugs.Auth do
    import Plug.Conn
    use SpotliveWeb, :controller
    alias SpotliveWeb.Router.Helpers
    alias Spotlive.UserService
    alias SpotliveWeb.JWTHelper
    require Logger

    def init(default), do: default
    def call(conn, _opts) do
      case get_req_header(conn, "authorization") do
        [token] ->
          case JWTHelper.verify(token) do
            {:ok, %{"user_id" => user_id}} ->
              user = UserService.get_user_by_user_id(user_id)
              session = %{:id => user.id, :username => user.username}
              Logger.warn("session: #{inspect(session)}")
              conn
              |> assign(:session, session)
            {:error, reason} ->
              Logger.error(reason)
              conn
              |> put_status(:unauthorized)
              |> json(%{"error": "Authentication failed"})
              |> halt()
          end
        _ -> 
          conn
          |> put_status(:unauthorized)
          |> json(%{"error": "Authentication failed"})
          |> halt()
          
      end
    end
  end