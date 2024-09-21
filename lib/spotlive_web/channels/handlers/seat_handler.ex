defmodule Spotlive.SeatsHandler do
  use Phoenix.Channel
  alias SpotliveWeb.CommonHelper
  alias Spotlive.StageMemoryService
  require Logger

  def handle_leave_seat(%{"stageId" => stageId}, socket) do
    session = socket.assigns.session
    username = socket.assigns.session.username
    userId = Map.get(session, :id)
    roundId = socket.assigns.roundId

    Logger.debug("stage: #{stageId}")

    case StageMemoryService.read_user_seat(roundId, userId) do
      {:ok, seatIdx} ->
        case StageMemoryService.delete_seat(roundId, seatIdx, userId) do
          {:ok, 0} ->
            {:noreply, socket}

          {:ok, keys} ->
            broadcast!(socket, "leave:seat", %{
              message: "seat:cleared",
              session: session,
              seatIdx: seatIdx
            })

            {:noreply, socket}

          {:error, reason} ->
            broadcast!(socket, "leave:seat", %{
              message: "seat:excetpion",
              session: session,
              seatIdx: seatIdx
            })

            {:noreply, socket}
        end
    end
  end

  def handle_take_seat(%{"seatIdx" => seatIdx, "stageId" => stageId}, socket) do
    session = socket.assigns.session
    userId = Map.get(session, :id)
    roundId = socket.assigns.roundId

    Logger.debug("stage: #{stageId}")

    Logger.info("User #{userId} requests to take seat #{seatIdx} in round #{roundId}")

    case StageMemoryService.read_user_seat(roundId, userId) do
      # case. other seat idx has been already taken by same user
      {:ok, otherSeatIdx} when is_integer(otherSeatIdx) ->
        broadcast!(socket, "take:seat", %{
          message: "seat:taken:same:user",
          session: session,
          seatIdx: otherSeatIdx
        })

        {:noreply, socket}

      # case. user has not taken any seat yet
      {:ok, :empty} ->
        Logger.debug("User has not taken any seat yet, attempting to take seat #{seatIdx}")

        case StageMemoryService.read_seat_availability(seatIdx, roundId) do
          # case. seat is available
          :empty ->
            StageMemoryService.take_seat(roundId, seatIdx, userId)

            broadcast!(socket, "take:seat", %{
              message: "seat:taken",
              session: session,
              seatIdx: seatIdx
            })

            {:noreply, socket}

          # case. seat is reserved
          :reserved ->
            broadcast!(socket, "take:seat", %{
              message: "seat:reserved",
              session: session,
              seatIdx: seatIdx
            })

            {:noreply, socket}

          # case. error handling
          :error ->
            broadcast!(socket, "take:seat", %{
              message: "seat:exception",
              session: session,
              seatIdx: seatIdx
            })

            {:noreply, socket}
        end

      # general server exception handling
      {:error, reason} ->
        broadcast!(socket, "take:seat", %{
          message: "seat:exception",
          session: session,
          seatIdx: seatIdx,
          error: reason
        })

        {:noreply, socket}
    end
  end
end
