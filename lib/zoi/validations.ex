defmodule Zoi.Validations do
  @moduledoc """
  Module for defining and running validations.
  """

  @type validation :: mfa()
  @type validation_result :: {:ok, any()} | {:error, map()}

  @spec append_validations(Zoi.Type.t(), validation()) :: [validation()]
  def append_validations(schema, validation) do
    validations = [validation | schema.meta.validations]
    meta = %{schema.meta | validations: validations}
    %{schema | meta: meta}
  end

  @doc """
  Runs a list of validations against the input.
  """
  @spec run_validations(schema :: Zoi.Type.t(), input :: any()) :: validation_result()
  def run_validations(schema, input) do
    schema.meta.validations
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, input}, fn {mod, func, args}, {:ok, _input} ->
      case apply(mod, func, [schema, input] ++ args) do
        :ok -> {:cont, {:ok, input}}
        {:error, err} -> {:halt, {:error, err}}
      end
    end)
  end
end
