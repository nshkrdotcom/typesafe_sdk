defmodule TypeSafeSDK.Generated.Schemas.ChoiceQuestion do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.ChoiceQuestion`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:criteria, :type]
  defstruct [:criteria, :instructions, :type]

  @type t :: %__MODULE__{
          criteria: term(),
          instructions: String.t() | map() | [map()] | nil,
          type: String.t()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      criteria: {:map, :string, {:union, [:string, :map, {:array, :map}, :null]}},
      instructions: {:union, [:string, :map, {:array, :map}, :null]},
      type: {:const, "choice"}
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description:
          "Choice names and descriptions of when each applies. A choice without a description is interpreted by its name alone.",
        name: "criteria",
        nullable: false,
        required: true,
        type: {:map, :string, {:union, [:string, :map, {:array, :map}, :null]}}
      },
      %{
        description: "What the model should decide when choosing an option.",
        name: "instructions",
        nullable: true,
        required: false,
        type: {:union, [:string, :map, {:array, :map}, :null]}
      },
      %{
        description: "Identifies a question that selects one of the choices in criteria.",
        name: "type",
        nullable: false,
        required: true,
        type: {:const, "choice"}
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
