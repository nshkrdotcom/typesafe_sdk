defmodule TypeSafeSDK.Generated.Schemas.ChoiceAnswer do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.ChoiceAnswer`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:choice, :confidence, :probabilities, :type]
  defstruct [:choice, :confidence, :probabilities, :type]

  @type t :: %__MODULE__{
          choice: String.t(),
          confidence: number(),
          probabilities: term(),
          type: String.t()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      choice: :string,
      confidence: :number,
      probabilities: {:map, :string, :number},
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
          "The name of the choice with the highest probability among the question's criteria.",
        name: "choice",
        nullable: false,
        required: true,
        type: :string
      },
      %{
        description:
          "Confidence in the selected choice, from 0 to 1. Higher values indicate greater certainty; use lower values to flag uncertain selections for review.",
        name: "confidence",
        nullable: false,
        required: true,
        type: :number
      },
      %{
        description:
          "Probability of each choice in criteria, keyed by choice name, from 0 to 1. Shows how likely the alternatives are; values sum to approximately 1.",
        name: "probabilities",
        nullable: false,
        required: true,
        type: {:map, :string, :number}
      },
      %{
        description: "Identifies a selection from the requested choices.",
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
