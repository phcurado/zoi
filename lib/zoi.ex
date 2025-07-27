defmodule Zoi do
  @moduledoc """
  Documentation for `Zoi`.
  """

  defmodule Error do
    defexception [:message, :key, :path, :value]

    def exception(%__MODULE__{message: message, key: key}) do
      "#{key} #{message}"
    end
  end

  @type input :: any()
  @type result :: {:ok, any()} | {:error, map()}

  @doc """
  Parse input data against a schema.
  Accepts optional `strict: true` option to disable coercion.
  """
  @spec parse(schema :: Zoi.Type.t(), input :: input(), opts :: Keyword.t()) :: result()
  def parse(schema, input, opts \\ []) do
    Zoi.Type.parse(schema, input, opts)
  end

  # Implemented types
  defdelegate string(opts \\ []), to: Zoi.Types.String, as: :new
  defdelegate integer(opts \\ []), to: Zoi.Types.Integer, as: :new
  defdelegate optional(opts \\ []), to: Zoi.Types.Optional, as: :new
  defdelegate map(fields, opts \\ []), to: Zoi.Types.Map, as: :new

  # Validations
  defdelegate min(schema, min), to: Zoi.Validations.Min, as: :new
end
