defmodule TypeSafeSDK.RequestBudget do
  @moduledoc false

  alias TypeSafeSDK.Error

  @spec validate(term(), [String.t()]) :: :ok | {:error, Error.t()}
  def validate(nil, _path), do: :ok
  def validate(value, _path) when is_integer(value) and value > 0, do: :ok

  def validate(_value, path),
    do: {:error, Error.invalid_request(path, "must be a positive integer or nil")}

  @spec effective(pos_integer() | nil, keyword()) :: pos_integer() | nil
  def effective(client_default, opts) do
    case Keyword.fetch(opts, :max_request_bytes) do
      {:ok, value} -> value
      :error -> client_default
    end
  end

  @spec check(term(), pos_integer() | nil) :: :ok | {:error, Error.t()}
  def check(_body, nil), do: :ok

  def check(body, max_bytes) when is_integer(max_bytes) and max_bytes > 0 do
    actual_bytes = body |> Jason.encode_to_iodata!() |> IO.iodata_length()

    if actual_bytes <= max_bytes do
      :ok
    else
      {:error, Error.request_too_large(actual_bytes, max_bytes)}
    end
  rescue
    error in Jason.EncodeError ->
      {:error, Error.invalid_request(["request"], "request is not JSON-serializable", %{kind: error.__struct__})}
  end
end
