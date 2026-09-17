defmodule TypeSafeSDK.Generated.Schemas.NoulCriteria do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.NoulCriteria`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys []
  defstruct [false, true]

  @type t :: %__MODULE__{
          false: String.t() | map() | [map()] | nil,
          true: String.t() | map() | [map()] | nil
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      false: {:union, [:string, :map, {:array, :map}, :null]},
      true: {:union, [:string, :map, {:array, :map}, :null]}
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description: "What counts as a no answer.",
        name: "false",
        nullable: true,
        required: false,
        type: {:union, [:string, :map, {:array, :map}, :null]}
      },
      %{
        description: "What counts as a yes answer.",
        name: "true",
        nullable: true,
        required: false,
        type: {:union, [:string, :map, {:array, :map}, :null]}
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
