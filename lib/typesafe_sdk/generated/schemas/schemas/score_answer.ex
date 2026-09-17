defmodule TypeSafeSDK.Generated.Schemas.ScoreAnswer do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.ScoreAnswer`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:confidence, :legend, :probabilities, :score, :type]
  defstruct [:confidence, :legend, :probabilities, :score, :type]

  @type t :: %__MODULE__{
          confidence: number(),
          legend: term(),
          probabilities: term(),
          score: number(),
          type: String.t()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      confidence: :number,
      legend: {:map, :string, {:union, [:string, :map, array: :map]}},
      probabilities: {:map, :string, :number},
      score: :number,
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
          "Confidence in the score, from 0 to 1. Higher values indicate greater certainty; use lower values to flag uncertain ratings for review.",
        name: "confidence",
        nullable: false,
        required: true,
        type: :number
      },
      %{
        description:
          "The requested criteria mapped to their score levels, so you can interpret the score.",
        name: "legend",
        nullable: false,
        required: true,
        type: {:map, :string, {:union, [:string, :map, array: :map]}}
      },
      %{
        description:
          "Probability of each score level, from 0 to 1, using the same keys as legend. Shows how likely the alternatives are; values sum to approximately 1.",
        name: "probabilities",
        nullable: false,
        required: true,
        type: {:map, :string, :number}
      },
      %{
        description:
          "Expected score: the probability-weighted average of the rubric levels. May fall between integer levels.",
        name: "score",
        nullable: false,
        required: true,
        type: :number
      },
      %{
        description: "Identifies a rating against the requested score levels.",
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
