defprotocol Zoi.Validations.Lt do
  @moduledoc false

  @fallback_to_any true

  @doc """
  Sets the exclusive maximum constraint on the schema.
  Each type implements this to set the appropriate field (e.g., lt for Integer, lt for Number).
  Custom error messages can be passed via opts[:error].
  """
  @spec set(Zoi.schema(), term(), Zoi.options()) :: Zoi.schema()
  def set(schema, value, opts \\ [])

  @doc """
  Validates the input against the constraint value.
  The value is passed explicitly rather than read from the schema.
  """
  @spec validate(Zoi.schema(), Zoi.input(), term(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, value, opts \\ [])
end

defimpl Zoi.Validations.Lt, for: Any do
  def set(schema, value, opts) do
    Zoi.refine(schema, {Zoi.Refinements, :refine, [[lt: value], opts]})
  end

  def validate(_schema, _input, _value, _opts), do: :ok
end
