defmodule Zoi.Validations.Integer do
  @moduledoc false

  # Accepts floats with no fractional part, such as `1.0`. The JSON Schema
  # decoder refines `Zoi.number/1` with this check for `"type": "integer"`,
  # and the encoder maps it back to `type: :integer`.

  @spec validate(Zoi.schema(), Zoi.input()) :: :ok | {:error, Zoi.Error.t()}
  def validate(_schema, input) when input == trunc(input), do: :ok
  def validate(_schema, _input), do: {:error, Zoi.Error.invalid_type(:integer)}
end
