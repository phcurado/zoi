defprotocol Zoi.Validations.Base64Url do
  @moduledoc false

  @fallback_to_any true

  @spec validate(Zoi.schema(), Zoi.input(), Zoi.options()) :: :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, opts)
end

defimpl Zoi.Validations.Base64Url, for: Any do
  def validate(_schema, _input, _opts), do: :ok
end
