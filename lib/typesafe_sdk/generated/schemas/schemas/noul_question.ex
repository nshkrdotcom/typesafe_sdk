defmodule TypeSafeSDK.Generated.Schemas.NoulQuestion do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.NoulQuestion`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:type]
  defstruct [:criteria, :instructions, :type]

  @type t :: %__MODULE__{
          criteria: TypeSafeSDK.Generated.Schemas.NoulCriteria.t() | nil,
          instructions: String.t() | map() | [map()] | nil,
          type: String.t()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      criteria: {:union, [{TypeSafeSDK.Generated.Schemas.NoulCriteria, :t}, :null]},
      instructions: {:union, [:string, :map, {:array, :map}, :null]},
      type: {:const, "noul"}
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description: "Criteria clarifying what counts as a yes or no answer.",
        name: "criteria",
        nullable: true,
        required: false,
        type: {:union, [{TypeSafeSDK.Generated.Schemas.NoulCriteria, :t}, :null]}
      },
      %{
        description: "The yes/no question or statement to evaluate.",
        name: "instructions",
        nullable: true,
        required: false,
        type: {:union, [:string, :map, {:array, :map}, :null]}
      },
      %{
        description: "Identifies a yes/no question or statement.",
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
