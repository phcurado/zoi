defprotocol Zoi.Validations.Lt do
  @moduledoc false

  @spec validate(Zoi.schema(), Zoi.input(), Zoi.options()) :: :ok | {:error, term()}
  def validate(schema, input, opts)

  @doc """
  Sets the exclusive maximum constraint on the schema.
  """
  @spec set(Zoi.schema(), term()) :: Zoi.schema()
  def set(schema, value)
end
