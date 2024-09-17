defmodule SpotliveWeb.UserController do
  use SpotliveWeb, :controller
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserDatabaseService

  def session(conn, _params) do
    session = conn.assigns[:session]
    conn
    |> put_status(200)
    |> json(session)
  end

  def signin(conn, %{"username" => username, "password" => password}) do
    case UserDatabaseService.authenticate_user(username, password) do
      {:error, message} -> 
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
      {:ok, user} -> 
        token = JWTHelper.generate(user.id)
        conn
        |> put_status(200)
        |> json(%{token: token})
    end
    
  end

  def signup(conn, %{"username" => username, "password" => password}) do
    case UserDatabaseService.get_user_by_username(username) do
      nil ->
        # If the user doesn't exist, proceed with creation
        user_params = %{"username" => username, "password" => password}

        case UserDatabaseService.create(user_params) do
          {:ok, payload} ->
            conn
            |> put_status(:created)
            |> json(%{token: payload[:token]})

          {:error, changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
        end

      _user ->
        # If the username is already taken
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Username already taken"})
    end
  end
end