defmodule Zoi.Types.Float do
  @moduledoc false

  use Zoi.Type.Def, fields: [coerce: false]

  def opts() do
    Zoi.Types.Keyword.new(Zoi.Opts.shared_metadata(), strict: true)
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      cond do
        is_float(input) ->
          {:ok, input}

        coerce and is_binary(input) ->
          coerce_integer(schema, input)

        true ->
          error(schema)
      end
    end

    defp coerce_integer(schema, input) do
      case Float.parse(input) do
        {float, ""} -> {:ok, float}
        _error -> error(schema)
      end
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:float, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: float())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
