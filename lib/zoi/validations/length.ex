defprotocol Zoi.Validations.Length do
  @moduledoc false

  @fallback_to_any true

  @spec validate(Zoi.schema(), Zoi.input(), Zoi.options()) :: :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, opts)

  @doc """
  Sets the exact length constraint value on the schema.
  Implementations should ensure the constraint stays mutually exclusive with other length bounds.
  Custom error messages can be passed via opts[:error].
  """
  @spec set(Zoi.schema(), non_neg_integer(), Zoi.options()) :: Zoi.schema()
  def set(schema, value, opts \\ [])
end

defimpl Zoi.Validations.Length, for: Any do
  def set(schema, value, opts) do
    Zoi.refine(schema, {Zoi.Refinements, :refine, [[length: value], opts]})
  end

  def validate(_schema, _input, _opts), do: :ok
end
