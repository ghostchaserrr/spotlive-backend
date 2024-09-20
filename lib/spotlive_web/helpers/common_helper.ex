defmodule SpotliveWeb.CommonHelper do
  def mapToTuple(map) do
    values_tuple = map |> Map.values() |> List.to_tuple()
  end

  def construct_users_map(users) do
    Enum.into(users, %{}, fn user ->
      id = Map.get(user, :id) || Map.get(user, "id")
      username = Map.get(user, :username) || Map.get(user, "username")
      {id, username}
    end)
  end

  def construct_seats_map(seats) do
    Enum.into(seats, %{}, fn seat ->
      seatIdx = Map.get(seat, :seatIdx) || Map.get(seat, "seatIdx")
      userId = Map.get(seat, :userId) || Map.get(seat, "userId")
      {seatIdx, userId}
    end)
  end
end
