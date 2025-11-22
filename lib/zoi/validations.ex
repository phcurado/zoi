defmodule Zoi.Validations do
  @moduledoc false

  @type value :: any()
  @type input :: any()
  @type opts :: keyword()

  @spec run_validations(list({module(), {value(), opts()} | nil}), Zoi.Type.t(), input()) ::
          :ok | {:error, [Zoi.Error.t()]}
  def run_validations(validations, schema, input) do
    validations
    |> Enum.reduce([], fn {module, constraint_value}, acc ->
      case constraint_value do
        nil ->
          acc

        {value, opts} ->
          case module.validate(schema, input, value, opts) do
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
