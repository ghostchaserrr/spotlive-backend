defmodule Spotlive.ReactionsHandler do
  use Phoenix.Channel
  alias SpotliveWeb.CommonHelper
  alias Spotlive.ReactionsMemoryService
  alias Spotlive.ReactionsManager
  alias Spotlive.StageMemoryService
  require Logger

  def handle_send_reaction(%{"reaction" => reaction, "stageId" => stageId}, socket) do
    session = socket.assigns.session
    username = session.username
    user_id = Map.get(session, :id)
    roundId = socket.assigns.roundId

    case StageMemoryService.read_live_round_phase(stageId) do
      phase when phase == "performing" ->
        process_reaction(reaction, roundId, username, socket, session)

      _ ->
        broadcast_error(socket, "error:invalid:phase")
    end

    {:noreply, socket}
  end

  defp process_reaction(reaction, roundId, username, socket, session) do
    case ReactionsManager.get_reaction_index(reaction) do
      {:ok, idx} ->
        case ReactionsMemoryService.store_reaction(roundId, username, idx, reaction) do
          {:ok, _response} ->
            broadcast_reaction_received(socket, session, reaction, idx)

          {:error, _reason} ->
            broadcast_error(socket, "error:send:exception")
        end

      {:error, _reason} ->
        broadcast_error(socket, "error:send:exception")
    end
  end

  defp broadcast_reaction_received(socket, session, reaction, index) do
    broadcast!(socket, "send:reaction", %{
      message: "reaction:received",
      session: session,
      reaction: reaction,
      index: index
    })
  end

  defp broadcast_error(socket, message) do
    broadcast!(socket, "send:reaction", %{message: message})
  end
end
