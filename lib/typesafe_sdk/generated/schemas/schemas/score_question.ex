defmodule TypeSafeSDK.Generated.Schemas.ScoreQuestion do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.ScoreQuestion`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:criteria, :type]
  defstruct [:criteria, :instructions, :type]

  @type t :: %__MODULE__{
          criteria: [String.t() | map() | [map()]],
          instructions: String.t() | map() | [map()] | nil,
          type: String.t()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      criteria: {:array, {:union, [:string, :map, array: :map]}},
      instructions: {:union, [:string, :map, {:array, :map}, :null]},
      type: {:const, "score"}
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description:
          "Ordered descriptions of the score levels. Each description's position determines its score, starting at zero.",
        name: "criteria",
        nullable: false,
        required: true,
        type: {:array, {:union, [:string, :map, array: :map]}}
      },
      %{
        description: "What the model should rate.",
        name: "instructions",
        nullable: true,
        required: false,
        type: {:union, [:string, :map, {:array, :map}, :null]}
      },
      %{
        description: "Identifies a question that rates the content using the levels in criteria.",
        name: "type",
        nullable: false,
        required: true,
        type: {:const, "score"}
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
