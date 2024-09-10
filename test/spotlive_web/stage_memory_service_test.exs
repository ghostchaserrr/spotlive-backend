defmodule Spotlive.StageMemoryServiceTest do
  use ExUnit.Case
  alias Spotlive.StageMemoryService
  require Logger

  @stageId "stage-1"
  @userId 1
  @username "ghostchaser"
  @seatIdx 1

  setup do
    Redix.command!(:redix, ["FLUSHDB"])
    :ok
  end

  test "case. should store connected user" do
    # Call the function
    StageMemoryService.store_connected_user(@stageId, @userId, @username)
    username = StageMemoryService.read_username(@stageId, @userId)

    users = StageMemoryService.read_users(@stageId)
    assert username == @username
  end

  test "case. should remove connected user" do
    StageMemoryService.delete_connected_user(@stageId, @userId)    

    username = StageMemoryService.read_username(@stageId, @userId)
    assert username == nil

    users = StageMemoryService.read_users(@stageId)
    assert length(users) == 0


  end


  test "case. should store taken seat" do
    StageMemoryService.store_taken_seat(@stageId, @seatIdx, @userId)

    seatIdx = StageMemoryService.read_seat_user(@stageId, @seatIdx)

    seats = StageMemoryService.read_seats(@stageId)

    res = Enum.all?(seats, fn %{userId: userId, seatIdx: seatIdx} ->
      userId == @userId and seatIdx == @seatIdx
    end)

    assert res == true  
    assert seatIdx == @seatIdx
  end

  test "case. should clear seat" do
    StageMemoryService.delete_taken_seat(@stageId, @seatIdx, @userId)

    seatIdx = StageMemoryService.read_seat_user(@stageId, @seatIdx)
    seats = StageMemoryService.read_seats(@stageId)
    assert length(seats) == 0

    assert length(seats) == 0;
    assert seatIdx == nil

  end

  test "case. should store stage performer" do
    StageMemoryService.store_stage_performer(@stageId, @userId, @username)

    performer = StageMemoryService.read_performer(@stageId)

    assert performer != nil
    assert Map.get(performer, :id) == @userId
    assert Map.get(performer, :username) == @username

  end
end
