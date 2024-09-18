defmodule Spotlive.StageConfigs do
  def default_config(stage_id) when is_binary(stage_id) do
    IO.puts("arg")
    IO.puts("Stage ID: #{stage_id}")

    mappings = %{
      "stage-id-1" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-2" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-3" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-4" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-5" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-6" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-7" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-8" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-9" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      },
      "stage-id-10" => %{
        :preparing => 5000,
        :performing => 5000,
        :feedback => 5000,
        :finish => 5000
      }
    }

    config = mappings[stage_id]
    IO.puts("Config: #{inspect(config)}")
    config
  end
end
