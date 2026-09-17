defmodule TypeSafeSDK.Generated.Schemas.SystemOneRequest do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.SystemOneRequest`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:model, :questions, :state]
  defstruct [:model, :questions, :state]

  @type t :: %__MODULE__{
          model: String.t(),
          questions: term(),
          state: String.t() | map() | [map()]
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      model: :string,
      questions:
        {:map, :string,
         {:union,
          [
            {TypeSafeSDK.Generated.Schemas.NoulQuestion, :t},
            {TypeSafeSDK.Generated.Schemas.ChoiceQuestion, :t},
            {TypeSafeSDK.Generated.Schemas.ScoreQuestion, :t}
          ]}},
      state: {:union, [:string, :map, array: :map]}
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description:
          "Name or alias of the model to use. Available names are returned by GET /v1/models.",
        name: "model",
        nullable: false,
        required: true,
        type: :string
      },
      %{
        description:
          "Questions to ask about the content, each with a name you choose. The response uses those names to identify the answers.",
        name: "questions",
        nullable: false,
        required: true,
        type:
          {:map, :string,
           {:union,
            [
              {TypeSafeSDK.Generated.Schemas.NoulQuestion, :t},
              {TypeSafeSDK.Generated.Schemas.ChoiceQuestion, :t},
              {TypeSafeSDK.Generated.Schemas.ScoreQuestion, :t}
            ]}}
      },
      %{
        description: "The content all questions in this request refer to.",
        name: "state",
        nullable: false,
        required: true,
        type: {:union, [:string, :map, array: :map]}
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
