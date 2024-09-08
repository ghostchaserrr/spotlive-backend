defmodule Spotlive.Repo do
  use Ecto.Repo,
    otp_app: :spotlive,
    adapter: Ecto.Adapters.Postgres
end
