defmodule Spotlive.UserDatabaseService do
    alias Spotlive.Repo
    alias SpotliveWeb.JWTHelper
    alias Spotlive.Accounts.User
  
    def get_user_by_username(username) do
      Repo.get_by(User, username: username)
    end

    def get_user_by_user_id(id) do
      Repo.get_by(User, id: id)
    end


    def create(attrs) do
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, user} ->
          token = JWTHelper.generate(user.id)
          {:ok, %{user: user, token: token}}
        error ->
          error
      end
    end
  
    def authenticate_user(username, password) do
      user = get_user_by_username(username)
  
      case user do
        nil ->
          {:error, "Invalid username or password"}
  
        user ->
          if Bcrypt.verify_pass(password, user.password_hash) do
            {:ok, user}
          else
            {:error, "Invalid username or password"}
          end
      end
    end
  end