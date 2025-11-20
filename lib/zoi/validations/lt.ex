defprotocol Zoi.Validations.Lt do
  @moduledoc false

  @spec validate(Zoi.schema(), Zoi.input(), Zoi.options()) :: :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, opts)

  @doc """
  Sets the exclusive maximum constraint on the schema.
  Each type implements this to set the appropriate field (e.g., lt for Integer, lt for Number).
  Custom error messages can be passed via opts[:error].
  """
  @spec set(Zoi.schema(), term(), Zoi.options()) :: Zoi.schema()
  def set(schema, value, opts \\ [])
end
