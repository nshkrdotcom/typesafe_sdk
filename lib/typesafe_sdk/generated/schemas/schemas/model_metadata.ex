defmodule TypeSafeSDK.Generated.Schemas.ModelMetadata do
  @moduledoc """
  Generated Typesafe Sdk type module `TypeSafeSDK.Generated.Schemas.ModelMetadata`.
  """

  alias TypeSafeSDK.Generated.RuntimeSchema, as: RuntimeSchema

  @enforce_keys [:description, :name, :release_date]
  defstruct [:description, :name, :release_date]

  @type t :: %__MODULE__{
          description: String.t(),
          name: String.t(),
          release_date: String.t()
        }
  @doc false
  @spec __fields__(atom()) :: keyword()
  def __fields__(type \\ :t)

  def __fields__(:t) do
    [
      description: :string,
      name: :string,
      release_date: :string
    ]
  end

  @doc false
  @spec __openapi_fields__(atom()) :: [map()]
  def __openapi_fields__(type \\ :t)

  def __openapi_fields__(:t) do
    [
      %{
        description: "Human-readable description of the model and its capabilities.",
        name: "description",
        nullable: false,
        required: true,
        type: :string
      },
      %{
        description: "Model name or alias accepted by the request's model field.",
        name: "name",
        nullable: false,
        required: true,
        type: :string
      },
      %{
        description: "Model release date, formatted as YYYY-MM-DD.",
        name: "release_date",
        nullable: false,
        required: true,
        type: :string
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
