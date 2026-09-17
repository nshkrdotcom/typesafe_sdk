defmodule TypeSafeSDK.Generated.Schemas.NoulAnswer do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.NoulAnswer`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:noul, :type]
  defstruct [:noul, :type]

  @type t :: %__MODULE__{
          noul: number(),
          type: String.t()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      noul: :number,
      type: {:const, "noul"}
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description:
          "Probability of a yes answer or a true statement, from 0 to 1. Values near 1 favor yes or true, values near 0 favor no or false, and values near 0.5 indicate uncertainty.",
        name: "noul",
        nullable: false,
        required: true,
        type: :number
      },
      %{
        description: "Identifies a yes/no answer.",
        name: "type",
        nullable: false,
        required: true,
        type: {:const, "noul"}
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
