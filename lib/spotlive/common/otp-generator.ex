defmodule Spotlive.OtpService do
  def generate_otp do
    # generates a random number between 1000 and 9999
    :rand.uniform(9_000) + 1_000
  end
end
