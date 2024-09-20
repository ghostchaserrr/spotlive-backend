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

  def handle_info(:after_join, socket) do
    session = socket.assigns.session
    roundId = socket.assigns.roundId
    userId = Map.get(session, :id)
    username = Map.get(session, :username)

    broadcast!(socket, "user:join", %{
      :message => "A new user has joined the stage",
      :session => session
    })

    push(socket, "notification", %{notification: "Welcome to the stage"})

    push(socket, "user:join", %{
      :message => "A new user has joined the stage",
      :session => session
    })

    Logger.info("User connected to stage: #{roundId}")

    StageMemoryService.store_connected_user(roundId, userId, username)

    {:noreply, socket}
  end

  # def handle_take_stage(conn, socket) do
  #   session = socket.assigns.session
  #   username = socket.assigns.session.username
  #   userId = Map.get(session, :id)
  #   roundId = socket.assigns.roundId

  #   StageMemoryService.store_stage_performer(roundId, userId, username)

  #   broadcast!(socket, "take:stage", %{
  #     message: "performer selected",
  #     session: session,
  #     roundId: roundId
  #   })

  #   {:noreply, socket}
  # end

  # Handle incoming messages if necessary
  def handle_in(event, params, socket) do
    case event do
      # "take:stage" ->
      #   handle_take_stage(params, socket)

      "leave:seat" ->
        Spotlive.SeatsHandler.handle_leave_seat(params, socket)

      "take:seat" ->
        Spotlive.SeatsHandler.handle_take_seat(params, socket)

      _ ->
        push(socket, "error", "invalid event")
        {:noreply, socket}
    end
  end

  def terminate(_reason, socket) do
    session = socket.assigns.session
    username = socket.assigns.session.username
    roundId = socket.assigns.roundId
    userId = Map.get(session, :id)

    # case. remove user from stage
    StageMemoryService.delete_connected_user(roundId, userId)

    broadcast!(socket, "user:leave", %{
      :message => "user has left the stage",
      :session => session
    })

    :ok
  end
end
