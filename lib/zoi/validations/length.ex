defprotocol Zoi.Validations.Length do
  @moduledoc false

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
