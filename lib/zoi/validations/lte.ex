defprotocol Zoi.Validations.Lte do
  @moduledoc false

  @spec validate(Zoi.schema(), Zoi.input(), Zoi.options()) :: :ok | {:error, String.t()}
  def validate(schema, input, opts)
end
