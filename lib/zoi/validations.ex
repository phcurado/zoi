defmodule Zoi.Validations do
  @moduledoc false

  @type value :: any()
  @type input :: any()
  @type opts :: keyword()

  @spec run_validations(list({module(), {value(), opts()} | nil}), Zoi.Type.t(), input()) ::
          :ok | {:error, [Zoi.Error.t()]}
  def run_validations(validations, schema, input) do
    do_run_validations(validations, schema, input, [])
  end

  defp do_run_validations([], _schema, _input, []), do: :ok
  defp do_run_validations([], _schema, _input, errors), do: {:error, Enum.reverse(errors)}

  defp do_run_validations([{_module, nil} | rest], schema, input, errors) do
    do_run_validations(rest, schema, input, errors)
  end

  defp do_run_validations([{module, {value, opts}} | rest], schema, input, errors) do
    case module.validate(schema, input, value, opts) do
      :ok -> do_run_validations(rest, schema, input, errors)
      {:error, error} -> do_run_validations(rest, schema, input, [error | errors])
    end
  end

  @spec maybe_set_validation(Zoi.Type.t(), module(), value()) :: Zoi.Type.t()
  def maybe_set_validation(schema, _module, nil), do: schema

  def maybe_set_validation(schema, module, {value, opts}) do
    module.set(schema, value, opts)
  end

  def maybe_set_validation(schema, module, value) do
    module.set(schema, value, [])
  end

  @spec unwrap_validation(value()) :: value()
  def unwrap_validation(nil), do: nil
  def unwrap_validation({value, _opts}), do: value

  @spec multiple_of?(number() | Decimal.t(), number() | Decimal.t()) :: boolean()
  def multiple_of?(input, value) when is_integer(input) and is_integer(value) do
    rem(input, value) == 0
  end

  def multiple_of?(input, value) do
    {:ok, decimal_input} = Decimal.cast(input)
    {:ok, decimal_value} = Decimal.cast(value)

    decimal_input
    |> Decimal.rem(decimal_value)
    |> Decimal.eq?(0)
  end

  # The JSON Schema decoder refines `Zoi.number/1` with this check for
  # `"type": "integer"`, and the encoder maps it back to `type: :integer`.
  @spec validate_integer(input(), opts()) :: :ok | {:error, Zoi.Error.t()}
  def validate_integer(input, _opts) when input == trunc(input), do: :ok
  def validate_integer(_input, _opts), do: {:error, Zoi.Error.invalid_type(:integer)}
end
