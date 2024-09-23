defmodule Spotlive.TextContentHandler do
  use Phoenix.Channel
  alias SpotliveWeb.CommonHelper
  alias Spotlive.ContentMemoryService
  alias Spotlive.StageMemoryService
  require Logger

  defp broadcast_success(socket, session, text) do
    broadcast!(socket, "receive:content", %{
      message: "content:received:text",
      session: session,
      text: text
    })
  end

  defp store_content_text(params, socket) do
    session = socket.assigns.session
    text = Map.get(params, "text")
    userId = Map.get(session, :id)
    roundId = socket.assigns.roundId

    case ContentMemoryService.store_content_text(roundId, userId, text) do
      :success ->
        broadcast_success(socket, session, text)

      :error ->
        broadcast_error(socket, "error:content:exception")
    end
  end

  defp process_store_text(params, socket) do
    roundId = socket.assigns.roundId
    session = socket.assigns.session

    case StageMemoryService.read_performer(roundId) do
      [] ->
        broadcast_error(socket, "error:missing:performer")

      performer ->
        performerId = Map.get(performer, :id)
        userId = Map.get(session, :id)

        # case. we expect current user to be selected as performer to be able to send content
        cond do
          performerId == userId -> store_content_text(params, socket)
          performerId !== userId -> broadcast_error(socket, "error:content:invalid:user")
        end

      {:error, reason} ->
        broadcast_error(socket, "error:content:exception")
    end
  end

  defp broadcast_error(socket, message) do
    broadcast!(socket, "receive:content", %{message: message})
  end

  def handle_send_text(params, socket) do
    stageId = Map.get(params, "stageId")

    case StageMemoryService.read_live_round_phase(stageId) do
      phase when phase == "performing" ->
        process_store_text(params, socket)

      _ ->
        broadcast_error(socket, "error:invalid:phase")
    end

    {:noreply, socket}
  end
end
