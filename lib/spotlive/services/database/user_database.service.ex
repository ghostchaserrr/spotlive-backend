defmodule Spotlive.UserDatabaseService do
  alias Spotlive.Repo
  import Ecto.Query
  alias SpotliveWeb.JWTHelper
  alias Spotlive.Accounts.User
  require Logger

  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  def get_user_by_user_id(id) do
    Repo.get_by(User, id: id)
  end

  def bulk_get_users_by_ids(ids) do
    import Ecto.Query

    from(u in User, where: u.id in ^ids)
    |> Repo.all()
    |> Enum.map(fn user ->
      %{
        :id => user.id,
        :username => user.username
      }
    end)
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
        {:error, "error:credentials"}

      user ->
        if Bcrypt.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, "error:credentials"}
        end
    end
  end
end
