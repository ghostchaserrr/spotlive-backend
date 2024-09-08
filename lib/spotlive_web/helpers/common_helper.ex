



defmodule SpotliveWeb.CommonHelper do


    def mapToTuple(map) do
        values_tuple = map |> Map.values() |> List.to_tuple()
    end
  
  end