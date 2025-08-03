defmodule Zoi.Types.Float do
  @moduledoc false

  use Zoi.Type.Def, fields: [coerce: false]

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
          coerce_integer(input)

        true ->
          error()
      end
    end

    defp coerce_integer(input) do
      case Float.parse(input) do
        {float, ""} -> {:ok, float}
        _error -> error()
      end
    end

    defp error() do
      {:error, "invalid float type"}
    end
  end
end
