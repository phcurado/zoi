defmodule Zoi.Types.Integer do
  @type t :: %__MODULE__{coerce: boolean(), meta: Zoi.Types.Base.t()}

  defstruct [:meta, coerce: false]

  @spec new(opts :: keyword()) :: t()
  def new(opts \\ []) do
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)
    struct!(__MODULE__, [{:meta, meta} | opts])
  end

  defimpl Zoi.Type do
    alias Zoi.Validations

    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      do_parse(input, coerce)
      |> then(fn
        {:ok, value} ->
          Validations.run_validations(schema, value)

        {:error, _reason} = error ->
          error
      end)
    end

    defp do_parse(input, coerce) do
      cond do
        is_integer(input) ->
          {:ok, input}

        coerce and is_binary(input) ->
          coerce_integer(input)

        true ->
          error()
      end
    end

    defp coerce_integer(input) do
      case Integer.parse(input) do
        {integer, ""} -> {:ok, integer}
        _error -> error()
      end
    end

    defp error() do
      {:error, Zoi.Error.add_error("invalid integer type")}
    end
  end

  # Validations

  defimpl Zoi.Validations.Min do
    alias Zoi.Validations

    def new(schema, min) do
      Validations.append_validations(schema, {Zoi.Validations.Min, :validate, [min]})
    end

    def validate(%Zoi.Types.Integer{}, input, min) do
      if input >= min do
        :ok
      else
        {:error, Zoi.Error.add_error("minimum value is #{min}")}
      end
    end
  end

  defimpl Zoi.Validations.Max do
    alias Zoi.Validations

    def new(schema, max) do
      Validations.append_validations(schema, {Zoi.Validations.Max, :validate, [max]})
    end

    def validate(%Zoi.Types.Integer{}, input, max) do
      if input <= max do
        :ok
      else
        {:error, Zoi.Error.add_error("maximum value is #{max}")}
      end
    end
  end
end
