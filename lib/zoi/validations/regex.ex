defprotocol Zoi.Validations.Regex do
  @moduledoc false

  @fallback_to_any true

  @spec validate(Zoi.schema(), Zoi.input(), term(), keyword(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, value, regex_opts, opts)
end

defimpl Zoi.Validations.Regex, for: Any do
  def validate(_schema, _input, _value, _regex_opts, _opts), do: :ok
end
