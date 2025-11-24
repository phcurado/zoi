defprotocol Zoi.Validations.OneOf do
  @moduledoc false

  @fallback_to_any true

  @spec validate(Zoi.schema(), Zoi.input(), list(), Zoi.options()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, values, opts \\ [])
end

defimpl Zoi.Validations.OneOf, for: Any do
  def validate(_schema, input, values, opts) do
    if input in values do
      :ok
    else
      {:error, Zoi.Error.not_in_values(values, opts)}
    end
  end
end
