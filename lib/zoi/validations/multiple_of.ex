defprotocol Zoi.Validations.MultipleOf do
  @moduledoc false

  @fallback_to_any true

  @doc """
  Sets the multiple_of constraint value on the schema.
  The value must be a positive number that the input must be divisible by.
  Custom error messages can be passed via opts[:error].
  """
  @spec set(Zoi.schema(), term(), Zoi.options()) :: Zoi.schema()
  def set(schema, value, opts)

  @doc """
  Validates input is a multiple of the given value.
  The value is passed explicitly, not read from the schema.
  Used by both field-based validation and :validation effects.
  """
  @spec validate(Zoi.schema(), Zoi.input(), term(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, value, opts)
end

defimpl Zoi.Validations.MultipleOf, for: Any do
  def set(schema, value, opts) do
    Zoi.refine(schema, {Zoi.Validations.MultipleOf, :validate, [value, opts]})
  end

  def validate(_schema, _input, _value, _opts), do: :ok
end
