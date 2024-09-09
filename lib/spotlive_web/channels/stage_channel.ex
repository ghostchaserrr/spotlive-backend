defmodule SpotliveWeb.StageChannel do
  use Phoenix.Channel
  SpotliveWeb.CommonHelper
  alias SpotliveWeb.CommonHelper
  alias Spotlive.StageMemoryService
  require Logger

  def join("stage:" <> stage_id, _payload, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :stageId, stage_id)}
  end

  def handle_info(:after_join, socket) do
    session = socket.assigns.session
    stageId = socket.assigns.stageId
    userId = Map.get(session, :id)
    username = Map.get(session, :username)

    broadcast!(socket, "viewer_joined", %{
      :message => "A new viewer has joined the stage",
      :session => session
    })

    push(socket, "notification", %{notification: "Welcome to the stage"})

    StageMemoryService.store_connected_user(stageId, userId, username)

    users = StageMemoryService.users(stageId)

    push(socket, "connected_users", users)

    {:noreply, socket}
  end

  def handle_leave_seat(%{"seatIdx" => seatIdx}, socket) do
    session = socket.assigns.session
    username = socket.assigns.session.username
    userId = Map.get(session, :id)
    stageId = socket.assigns.stageId

    Logger.info(
      "user requests to leave seat. user: #{userId}. stage #{stageId} seatIdx #{seatIdx}"
    )

    StageMemoryService.delete_taken_seat(stageId, seatIdx, userId)

    broadcast!(socket, "leave_seat", %{
      message: "seat has been cleared",
      session: session,
      seatIdx: seatIdx
    })

    {:noreply, socket}
  end

  def handle_take_stage(%{"stageId" => stageId}, socket) do
    session = socket.assigns.session
    username = socket.assigns.session.username
    userId = Map.get(session, :id)

    case StageMemoryService.has_stage_performer(stageId) do
      true ->
        push(socket, "error", %{:error => "stage_taken", :stageId => stageId})
        {:noreply, socket}

      false ->
        Logger.info("user requests to take stage. user: #{userId}. stage #{stageId}")
        StageMemoryService.store_stage_performer(stageId, userId, username)

        broadcast!(socket, "take_stage", %{
          message: "performer selected",
          session: session,
          stageId: stageId
        })

        {:noreply, socket}
    end
  end

  def handle_take_seat(%{"seatIdx" => seatIdx}, socket) do
    session = socket.assigns.session
    username = socket.assigns.session.username
    userId = Map.get(session, :id)
    stageId = socket.assigns.stageId

    Logger.info("user requests seat take. user: #{userId}. stage #{stageId} seatIdx #{seatIdx}")

    StageMemoryService.store_taken_seat(stageId, seatIdx, userId)

    broadcast!(socket, "take_seat", %{
      message: "seat has been taken",
      session: session,
      seatIdx: seatIdx
    })

    {:noreply, socket}
  end

  # Handle incoming messages if necessary
  def handle_in(event, params, socket) do
    case event do
      "take_stage" -> handle_take_stage(params, socket)
      "leave_seat" -> handle_leave_seat(params, socket)
      "take_seat" -> handle_take_seat(params, socket)
      _ -> 
        push(socket, "error", "invalid event")
        {:noreply, socket}
    end
  end

  def terminate(_reason, socket) do
    session = socket.assigns.session
    id = Map.get(session, :id)

    broadcast!(socket, "viewer_left", %{
      :message => "A viewer has left the stage",
      :session => session
    })

    :ok
  end
end
