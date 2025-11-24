defprotocol Zoi.Validations.EndsWith do
  @moduledoc false

  @fallback_to_any true

  @spec validate(Zoi.schema(), Zoi.input(), term(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, value, opts \\ [])
end

defimpl Zoi.Validations.EndsWith, for: Any do
  def validate(_schema, _input, _value, _opts), do: :ok
end
