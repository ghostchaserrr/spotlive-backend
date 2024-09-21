defmodule Spotlive.SmsService do
  require Logger
  alias HTTPoison.Response
  alias HTTPoison.Error

  @sms_service_url "https://smsservice.inexphone.ge/api/v1/sms/one"
  # Fetching from config
  @sms_service_key Application.fetch_env!(:spotlive, :sms_service_key)

  @spec send_sms(String.t(), String.t()) :: :ok | {:error, String.t()}
  def send_sms(phone, body) do
    headers = [
      {"Authorization", "Bearer #{@sms_service_key}"},
      {"Content-Type", "application/json"}
    ]

    Logger.debug("headers: #{inspect(headers)}")

    payload =
      %{phone: phone, subject: "VERIFY CODE", message: body, ignore_blacklist: true}
      |> Jason.encode!()

    Logger.debug("payload: #{payload}")

    HTTPoison.post(@sms_service_url, payload, headers, [])
    # case  do
    #   {:ok} ->
    #     Logger.info("SMS sent successfully. Response: #{body}")
    #     :ok

    #   {:ok} ->
    #     Logger.error("Failed to send SMS. Status code: #{status_code}, Response: #{body}")
    #     {:error, "SMS_SEND_FAILED"}

    #   {:error, %Error{reason: reason}} ->
    #     Logger.error("Error sending SMS: #{inspect(reason)}")
    #     {:error, "SMS_SEND_FAILED"}
    # end
  end
end
