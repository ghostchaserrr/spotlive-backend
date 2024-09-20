defmodule SpotliveWeb.StageGateways do
  use Phoenix.Socket
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserDatabaseService

  channel "stage:*", SpotliveWeb.StageChannel

  transport :websocket, Phoenix.Transports.WebSocket, check_origin: false

  def connect(%{"token" => token}, socket, _connect_info) do
    case JWTHelper.verify(token) do
      {:ok, %{"user_id" => user_id}} ->
        user = UserDatabaseService.get_user_by_user_id(user_id)
        session = %{:id => user.id, :username => user.username}
               
        {:ok, assign(socket, :session, session)}

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  # Socket id function, not used in this case, so we return nil
  def id(socket), do: "user_socket:#{socket.assigns.session.id}"
end
