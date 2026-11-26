defprotocol Zoi.Validations.Regex do
  @moduledoc false

  @fallback_to_any true

  @spec validate(Zoi.schema(), Zoi.input(), Regex.t(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, regex, opts)
end

defimpl Zoi.Validations.Regex, for: Any do
  def validate(_schema, _input, _regex, _opts), do: :ok
end
