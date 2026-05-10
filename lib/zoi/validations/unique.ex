defprotocol Zoi.Validations.Unique do
  @moduledoc false

  @fallback_to_any true

  @doc """
  Sets the unique items constraint on the schema.
  """
  @spec set(Zoi.schema(), boolean(), Zoi.options()) :: Zoi.schema()
  def set(schema, value, opts)

  @doc """
  Validates the input against the unique items constraint.
  """
  @spec validate(Zoi.schema(), Zoi.input(), term(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, value, opts)
end

defimpl Zoi.Validations.Unique, for: Any do
  def set(schema, value, opts) do
    Zoi.refine(schema, {Zoi.Validations.Unique, :validate, [value, opts]})
  end

  def validate(_schema, _input, _value, _opts), do: :ok
end
