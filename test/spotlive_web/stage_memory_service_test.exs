defmodule Spotlive.StageMemoryServiceTest do
    use ExUnit.Case
    alias Spotlive.StageMemoryService
  
    setup do
      Redix.command!(:redix, ["FLUSHDB"])
      :ok
    end
  
    test "stores a connected user" do
      stage_id = "stage-1"
      user_id = "user-123"
      username = "john_doe"
  
      # Call the function
      StageMemoryService.store_connected_user(stage_id, user_id, username)
  
      # Verify the user is stored in Redis
      key = "stage:#{stage_id}:users"
      {:ok, stored_username} = Redix.command(:redix, ["HGET", key, user_id])
      
      assert stored_username == username
    end
  
    test "stores a taken seat" do
      stage_id = "stage-1"
      seat_idx = "seat-1"
      user_id = "user-123"
  
      # Call the function
      StageMemoryService.store_taken_seat(stage_id, seat_idx, user_id)
  
      # Verify the seat is stored in Redis
      key = "stage:#{stage_id}:seats"
      {:ok, stored_user_id} = Redix.command(:redix, ["HGET", key, seat_idx])
      
      assert stored_user_id == user_id
    end
  end