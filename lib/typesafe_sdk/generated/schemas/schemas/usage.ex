defmodule TypeSafeSDK.Generated.Schemas.Usage do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.Usage`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:input_tokens, :output_tokens]
  defstruct [:input_tokens, :output_tokens]

  @type t :: %__MODULE__{
          input_tokens: integer(),
          output_tokens: integer()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      input_tokens: :integer,
      output_tokens: :integer
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description: "Number of billable input tokens used to evaluate the request.",
        name: "input_tokens",
        nullable: false,
        required: true,
        type: :integer
      },
      %{
        description:
          "Number of output tokens used to answer the questions. Output tokens are currently free of charge.",
        name: "output_tokens",
        nullable: false,
        required: true,
        type: :integer
      }
    ]
  end

  @doc false
  @spec __schema__(atom()) :: Sinter.Schema.t()
  def __schema__(type \\ :t) when is_atom(type) do
    RuntimeSchema.build_schema(__openapi_fields__(type))
  end

  @doc false
  @spec decode(map(), atom()) :: {:ok, term()} | {:error, term()}
  def decode(data, type \\ :t)

  def decode(data, type) when is_map(data) and is_atom(type) do
    RuntimeSchema.decode_module_type(__MODULE__, type, data)
  end
end
