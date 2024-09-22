defmodule Spotlive.SeatsHandler do
  use Phoenix.Channel
  alias SpotliveWeb.CommonHelper
  alias Spotlive.StageMemoryService
  require Logger

  defp process_leave_seat(params, socket) do
    session = socket.assigns.session
    username = socket.assigns.session.username
    userId = Map.get(session, :id)
    roundId = socket.assigns.roundId

    case StageMemoryService.read_user_seat(roundId, userId) do
      {:ok, seatIdx} ->
        case StageMemoryService.delete_seat(roundId, seatIdx, userId) do
          # case. seat is not available
          {:ok, 0} ->
            broadcast_error(socket, "leave:seat", "error:seat:missing")

          # case. seat is cleared
          {:ok, keys} ->
            Logger.debug("keys deleted: #{keys}")
            broadcast_success(seatIdx, "leave:seat", socket, "seat:cleared")

          {:error, reason} ->
            Logger.error(reason)
            broadcast_error(socket, "leave:seat", "error:seat:exception")
        end

      {:error, reason} ->
        Logger.error(reason)
        broadcast_error(socket, "leave:seat", "error:seat:exception")
    end
  end

  def handle_leave_seat(params, socket) do
    try do
      stageId = Map.get(params, "stageId")

      case StageMemoryService.read_live_round_phase(stageId) do
        phase when phase == "seating" ->
          process_leave_seat(params, socket)

        _ ->
          broadcast_error(socket, "take:seat", "error:invalid:phase")
      end
    rescue
      exception ->
        # Log failure
        Logger.error("failed to handle leave seat #{inspect(exception)}")
        broadcast_error(socket, "leave:seat", "error:seat:exception")
    end
  end

  defp broadcast_error(socket, event, message) do
    session = socket.assigns.session

    broadcast!(socket, event, %{
      message: message,
      session: session
    })

    {:noreply, socket}
  end

  def broadcast_success(seatIdx, event, socket, message) do
    session = socket.assigns.session

    broadcast!(socket, event, %{
      message: message,
      session: session,
      seatIdx: seatIdx
    })

    {:noreply, socket}
  end

  defp process_take_seat(params, socket) do
    session = socket.assigns.session
    username = socket.assigns.session.username
    userId = Map.get(session, :id)
    roundId = socket.assigns.roundId
    seatIdx = Map.get(params, "seatIdx")

    case StageMemoryService.read_user_seat(roundId, userId) do
      {:ok, :empty} ->
        case StageMemoryService.read_seat_availability(seatIdx, roundId) do
          # case. seat is available
          :empty ->
            StageMemoryService.take_seat(roundId, seatIdx, userId)
            broadcast_success(seatIdx, "take:seat", socket, "seat:taken")

          # case. seat is reserved
          :reserved ->
            broadcast_error(socket, "take:seat", "seat:reserved")

          :error ->
            broadcast_error(socket, "take:seat", "seat:exception")
        end

      {:ok, otherSeatIdx} ->
        broadcast_error(socket, "take:seat", "seat:taken:same:user")

      # case. general server exception
      {:error, reason} ->
        broadcast_error(socket, "take:seat", "seat:exception")
    end
  end

  def handle_take_seat(params, socket) do
    try do
      stageId = Map.get(params, "stageId")

      case StageMemoryService.read_live_round_phase(stageId) do
        phase when phase == "seating" ->
          process_take_seat(params, socket)

        _ ->
          broadcast_error(socket, "take:seat", "error:invalid:phase")
      end
    rescue
      exception ->
        # Log failure
        Logger.error("failed to handle take seat #{inspect(exception)}")
        broadcast_error(socket, "take:seat", "error:seat:exception")
    end
  end
end
