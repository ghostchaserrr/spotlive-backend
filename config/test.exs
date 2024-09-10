import Config

config :spotlive, redis_url: "redis://localhost:6379/1"  # Separate test DB in Redis
# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :spotlive, Spotlive.Repo,
  username: "admin",
  password: "admin",
  hostname: "localhost",
  database: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  port: 5435

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :spotlive, SpotliveWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PbcS49M9+iEg9he1V7Ge+GPKznYdXgr6psYytx5X1aE5xPCo3YQXoqZyxJY7kzlC",
  server: false

# In test we don't send emails
config :spotlive, Spotlive.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
