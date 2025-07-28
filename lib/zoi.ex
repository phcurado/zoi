defmodule Zoi do
  @moduledoc """
  Documentation for `Zoi`.
  """

  defmodule Error do
    defexception [:message, :key, :path, :value]

    @impl true
    def exception(opts) when is_list(opts) do
      struct!(__MODULE__, opts)
    end

    @impl true
    def message(%__MODULE__{key: key, message: msg}) when not is_nil(key) do
      "#{key} #{msg}"
    end

    def message(%__MODULE__{message: msg}), do: msg

    defimpl Inspect do
      def inspect(error, _opts) do
        error.message
      end
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
  defdelegate default(inner, value, opts \\ []), to: Zoi.Types.Default, as: :new
  defdelegate map(fields, opts \\ []), to: Zoi.Types.Map, as: :new

  # Validations
  defdelegate min(schema, min), to: Zoi.Validations.Min, as: :new
  defdelegate max(schema, max), to: Zoi.Validations.Max, as: :new
  defdelegate regex(schema, regex), to: Zoi.Validations.Regex, as: :new
  defdelegate email(schema, email), to: Zoi.Validations.Email, as: :new
end
