defmodule SpotliveWeb.StageChannel do
  use Phoenix.Channel
   SpotliveWeb.CommonHelper
  alias  SpotliveWeb.CommonHelper


  def join("stage:" <> stage_id, _payload, socket) do
    IO.puts("User is joining stage #{stage_id}")
    send(self(), :after_join)
    {:ok, assign(socket, :stage_id, stage_id)}
  end

  def handle_info(:after_join, socket) do
    session = socket.assigns.session;
    broadcast!(socket, "viewer_joined", %{:message => "A new viewer has joined the stage", :session => session})
    push(socket, "notification", %{notification: "Welcome to the stage"})
    
    userTuple = CommonHelper.mapToTuple(session)
    :ets.insert(:user_lookup, userTuple)

    # case. reconstruct connected users from ets
    connected_users = :ets.tab2list(:user_lookup) |> Enum.map(fn {id, username} -> %{"id" => id, "username" => username} end)
    push(socket, "connected_users", connected_users)

    {:noreply, socket}
  end

  def handle_leave_seat(%{"seatIdx" => seatIdx}, socket) do
    session = socket.assigns.session
    id = Map.get(session, :id)

    case :ets.lookup(:seat_lookup, seatIdx) do
      # case. returns either array of tuples or empty one if no match
      [{seatIdx, _existingUserId}] ->

        # case. remove entry from ets
        :ets.delete(:seat_lookup, seatIdx)

        # case. send message to all users 
        broadcast!(socket, "leave_seat", %{
          message: "seat has been cleared", 
          session: session,
          seatIdx: seatIdx,
          id: id
        })
        {:noreply, socket}
      [] ->

        # case. seat was not found in table
        handle_error(socket, "invalid event")
    end
  end

  def handle_take_stage(%{"stageIdx" => stageIdx}, socket) do
    
    # case. we allow user to take stage
    IO.puts("user requesting stage take")
    IO.puts(stageIdx)

    session = socket.assigns.session
    id = Map.get(session, :id)

    # case. check if target stage has user already
    case :ets.lookup(:speaker_lookup, stageIdx) do
      # case. returns either array of tuples or empty one if no match
      [{stageIdx, _existingUserId}] ->
        push(socket, "error", %{:error => "stage_taken", :stageIdx => stageIdx})
        {:noreply, socket}
      [] ->
        stageIdxUserIdxMap = %{"stageIdx" => stageIdx, "userId" => id}
        IO.inspect(stageIdxUserIdxMap)
  
        stageIdxUserIdxTuple = CommonHelper.mapToTuple(stageIdxUserIdxMap)
        IO.inspect(stageIdxUserIdxMap)
        
        :ets.insert(:speaker_lookup, stageIdxUserIdxTuple)
  
        broadcast!(socket, "take_stage", %{
          message: "stage has been taken", 
          session: session,
          stageIdx: stageIdx,
        })
        {:noreply, socket}
    end

    
  end

  def handle_take_seat(%{"seatIdx" => seatIdx}, socket) do
    IO.puts("user taking a seat in lobby")
    IO.puts(seatIdx)
    session = socket.assigns.session
    id = Map.get(session, :id)
  
    # Check if the seat is already taken
    case :ets.lookup(:seat_lookup, seatIdx) do
      # case. returns either array of tuples or empty one if no match
      [{seatIdx, _existingUserId}] ->
        # If seat is already taken, send custom error
        push(socket, "error", %{error: "seat_taken", seatIdx: seatIdx})
        {:noreply, socket}
      [] ->
        # If seat is not taken, proceed to take the seat
        seatIdxUserIdxMap = %{"seatIdx" => seatIdx, "userId" => id}
        IO.inspect(seatIdxUserIdxMap)
  
        seatIdxUserIdxTuple = CommonHelper.mapToTuple(seatIdxUserIdxMap)
        IO.inspect(seatIdxUserIdxTuple)
        
        :ets.insert(:seat_lookup, seatIdxUserIdxTuple)
  
        broadcast!(socket, "take_seat", %{
          message: "seat has been taken", 
          session: session,
          seatIdx: seatIdx,
          id: id
        })
        {:noreply, socket}
    end
  end

  def handle_error(socket, message) do
    error_message = %{error: message}
    push(socket, "error", error_message)
    {:noreply, socket}
  end

  # Handle incoming messages if necessary
  def handle_in(event, params, socket) do
    case event do
      "take_stage"  -> handle_take_stage(params, socket)
      "leave_seat"  -> handle_leave_seat(params, socket)
      "take_seat"   -> handle_take_seat(params, socket)
      _             -> handle_error(socket, "invalid event")
  
    end
  
  end

  def terminate(_reason, socket) do
    # case. get current user id and remove from ets table
    session = socket.assigns.session;
    id = Map.get(session, :id)
    :ets.delete(:user_lookup, id)

    case :ets.match(:seat_lookup, {:"$1", id}) do
      [[seat_id]] ->
        # Remove the tuple where the user ID matches
        :ets.delete(:seat_lookup, seat_id)
        IO.puts("Removed user #{id} from seat #{seat_id}")
    
        broadcast!(socket, "clear_seat", %{:message => "seat has been cleared", :seatIdx => seat_id, :id => id})

      _ ->
        IO.puts("User #{id} was not seated")
    end

    broadcast!(socket, "viewer_left", %{:message => "A viewer has left the stage", :session => session})
    :ok
  end
end