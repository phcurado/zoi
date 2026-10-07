defprotocol Zoi.Validations.Contains do
  @moduledoc false

  @fallback_to_any true

  @doc """
  Validates the number of items matching the contains schema.
  """
  @spec validate(Zoi.schema(), Zoi.input(), Zoi.schema(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, value, opts)
end

defimpl Zoi.Validations.Contains, for: Any do
  def validate(_schema, _input, _value, _opts) do
    :ok
  end
end
