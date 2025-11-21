defmodule Zoi.Validations do
  @moduledoc false

  @type value :: any()
  @type input :: any()
  @type opts :: keyword()

  @spec run_validations(list({module(), {value(), opts()}}), Zoi.Type.t(), input(), opts()) ::
          :ok | {:error, [Zoi.Error.t()]}
  def run_validations(validations, schema, input, opts) do
    validations
    |> Enum.reduce([], fn {module, constraint_value}, acc ->
      if constraint_value == nil do
        acc
      else
        case module.validate(schema, input, opts) do
          :ok -> acc
          {:error, error} -> [error | acc]
        end
      end
    end)
    |> case do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  @spec maybe_set_validation(Zoi.Type.t(), module(), value()) :: Zoi.Type.t()
  def maybe_set_validation(schema, _module, nil), do: schema

  def maybe_set_validation(schema, module, {value, opts}) do
    module.set(schema, value, opts)
  end

  def maybe_set_validation(schema, module, value) do
    module.set(schema, value)
  end

  @spec unwrap_validation(value()) :: value()
  def unwrap_validation(nil), do: nil
  def unwrap_validation({value, _opts}), do: value
end
