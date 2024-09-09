defmodule SpotliveWeb.StageGateways do
  use Phoenix.Socket
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserService


  channel "stage:*", SpotliveWeb.StageChannel

  transport(:websocket, Phoenix.Transports.WebSocket)

  def connect(%{"token" => token}, socket, _connect_info) do
    case JWTHelper.verify(token) do
      {:ok, %{"user_id" => user_id}} ->
        user = UserService.get_user_by_user_id(user_id)
        session = %{:id => user.id, :username => user.username}
        
        # case. load live round
        result = :ets.tab2list(:round_lookup)
        IO.inspect(result)
       
        {:ok, assign(socket, :session, session)}

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  # Socket id function, not used in this case, so we return nil
  def id(socket), do: "user_socket:#{socket.assigns.session.id}"
end
