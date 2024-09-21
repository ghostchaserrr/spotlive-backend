defmodule SpotliveWeb.UserController do
  use SpotliveWeb, :controller
  alias SpotliveWeb.JWTHelper
  alias Spotlive.UserDatabaseService
  alias Spotlive.UserMemoryService
  alias Spotlive.OtpService
  alias Spotlive.SmsService

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

  def otpCreate(conn, %{"username" => username, "phone" => phone}) do
    otp = OtpService.generate_otp()

    case UserMemoryService.store_otp(username, otp) do
      :ok ->
        # case. send sms
        SmsService.send_sms(phone, otp)

        conn
        |> put_status(:created)
        # Using map syntax consistently
        |> json(%{otp: otp})

      {:error, reason} ->
        Logger.error("Failed to store OTP for #{username}: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        # Use map syntax
        |> json(%{error: "internal server exception"})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "bad request"})
    end
  end

  # def otpVerify(conn, %{"username" => username}) do
  #   otp = OtpGenerator.generate_otp()

  #   case UserMemoryService.store_otp(username, otp) do
  #     conn
  #     |> put_status(:created)
  #     |> json(%{:otp => otp})
  #   end
  # end

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
            |> json(%{error: "error:invalid:params"})
        end

      _user ->
        # If the username is already taken
        conn
        |> put_status(:bad_request)
        |> json(%{error: "error:username:taken"})
    end
  end
end
