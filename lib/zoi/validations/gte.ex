defprotocol Zoi.Validations.Gte do
  @moduledoc false

  @fallback_to_any true

  @doc """
  Sets the minimum constraint value on the schema.
  Each type implements this to set the appropriate field (e.g., min_length for String, gte for Integer).
  Custom error messages can be passed via opts[:error].
  """
  @spec set(Zoi.schema(), term(), Zoi.options()) :: Zoi.schema()
  def set(schema, value, opts)

  @doc """
  Validates input against the constraint value.
  The value is passed explicitly, not read from the schema.
  Used by both field-based validation and :validation effects.
  """
  @spec validate(Zoi.schema(), Zoi.input(), term(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, value, opts)
end

defimpl Zoi.Validations.Gte, for: Any do
  def set(schema, value, opts) do
    Zoi.refine(schema, {Zoi.Validations.Gte, :validate, [value, opts]})
  end

  def validate(_schema, _input, _value, _opts), do: :ok
end
