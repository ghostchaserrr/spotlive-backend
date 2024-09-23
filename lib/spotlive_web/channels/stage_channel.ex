defmodule SpotliveWeb.StageChannel do
  use Phoenix.Channel
  alias SpotliveWeb.CommonHelper
  alias Spotlive.StageMemoryService
  alias Spotlive.SeatsHandler
  require Logger

  def join("stage:" <> roundId, _payload, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :roundId, roundId)}
  end

  defp broadcast_join_error(socket) do
    {session, _, _, _} = get_session(socket)

    push(socket, "user:join", %{
      :message => "user:join:exception",
      :session => session
    })
  end

  defp broadcast_join(socket) do
    {session, _, _, _} = get_session(socket)

    broadcast!(socket, "user:join", %{
      :message => "A new user has joined the stage",
      :session => session
    })

    push(socket, "notification", %{notification: "Welcome to the stage"})

    push(socket, "user:join", %{
      :message => "A new user has joined the stage",
      :session => session
    })
  end

  defp get_session(socket) do
    session = socket.assigns.session
    roundId = socket.assigns.roundId
    userId = Map.get(session, :id)
    username = Map.get(session, :username)

    {session, roundId, userId, username}
  end

  def handle_info(:after_join, socket) do
    {session, roundId, userId, username} = get_session(socket)

    case StageMemoryService.store_connected_user(roundId, userId, username) do
      {:ok, result} ->
        broadcast_join(socket)

      _ ->
        broadcast_join_error(socket)
    end

    {:noreply, socket}
  end

  def handle_in(event, params, socket) do
    case event do
      "leave:seat" ->
        Spotlive.SeatsHandler.handle_leave_seat(params, socket)

      "take:seat" ->
        Spotlive.SeatsHandler.handle_take_seat(params, socket)

      "send:reaction" ->
        Spotlive.ReactionsHandler.handle_send_reaction(params, socket)

      # case. handles textual content user input
      "send:content:text" ->
        Spotlive.TextContentHandler.handle_send_text(params, socket)

      _ ->
        push(socket, "error", "invalid event")
        {:noreply, socket}
    end
  end

  def terminate(_reason, socket) do
    {session, roundId, userId, username} = get_session(socket)

    # case. remove user from stage
    StageMemoryService.delete_connected_user(roundId, userId)

    # case. remove taken seat
    case StageMemoryService.read_user_seat(roundId, userId) do
      {:ok, seatIdx} ->
        Logger.warn("removing user seat: #{roundId} #{userId} #{seatIdx}")

        case StageMemoryService.delete_seat(roundId, seatIdx, userId) do
          {:ok, keys} ->
            Logger.warn("seat cleared upon termination #{seatIdx} #{userId} #{roundId}")

            broadcast!(socket, "leave:seat", %{
              message: "seat:cleared",
              session: session,
              seatIdx: seatIdx
            })
        end
    end

    broadcast!(socket, "user:leave", %{
      :message => "user has left the stage",
      :session => session
    })

    :ok
  end
end
