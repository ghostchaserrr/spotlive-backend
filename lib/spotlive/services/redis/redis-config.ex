defmodule Spotlive.RedisConfig do
    @moduledoc false
  
    use Application
  
    def start(_type, _args) do
      children = [
        # Other children...
        {Redix, {System.fetch_env!("REDIS_CONNECTION_URL"), [name: :redix]}}
      ]
  
      opts = [strategy: :one_for_one, name: Spotlive.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end