defmodule SpotliveWeb.JWTHelper do
  use Joken.Config

  @secret_key "your_secret_key"  # Use environment variables in production

  # Method to generate the JWT token
  def generate(user_id) do
    extra_claims = %{"user_id" => user_id}
    token_config()
    |> Joken.generate_and_sign!(extra_claims)
  end

  # Method to verify the JWT token
  def verify(token) do
    case Joken.verify_and_validate(token_config(), token, @secret_key) do
      {:ok, claims} -> 
        {:ok, claims}  # Return the user_id from claims if token is valid
      {:error, reason} -> 
        {:error, reason}  # Return the error reason if token is invalid
    end
  end

  # Define a token configuration that includes default claims
  defp token_config do
    Joken.Config.default_claims(iss: "spotlive", aud: "spotlive_audience")
  end
end