defprotocol Zoi.Validations.Lte do
  @moduledoc false

  @fallback_to_any true

  @spec validate(Zoi.schema(), Zoi.input(), Zoi.options()) :: :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, opts)

  @doc """
  Sets the maximum constraint value on the schema.
  Each type implements this to set the appropriate field (e.g., max_length for String, max for Integer).
  Custom error messages can be passed via opts[:error].
  """
  @spec set(Zoi.schema(), term(), Zoi.options()) :: Zoi.schema()
  def set(schema, value, opts \\ [])
end

defimpl Zoi.Validations.Lte, for: Any do
  def set(schema, value, opts) do
    Zoi.refine(schema, {Zoi.Refinements, :refine, [[lte: value], opts]})
  end

  def validate(_schema, _input, _opts), do: :ok
end
