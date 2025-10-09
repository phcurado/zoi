defmodule Zoi.Types.Number do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    opts = Keyword.merge([error: "invalid type: must be a number", coerce: false], opts)
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      cond do
        is_number(input) ->
          {:ok, input}

        coerce and is_binary(input) ->
          coerce_number(schema, input)

        true ->
          error(schema)
      end
    end

    defp coerce_number(schema, input) do
      case Integer.parse(input) do
        {number, ""} ->
          {:ok, number}

        {number, rest} ->
          case Float.parse(rest) do
            {float, ""} -> {:ok, number + float}
            _error -> error(schema)
          end

        _error ->
          error(schema)
      end
    end

    defp error(schema) do
      {:error, schema.meta.error}
    end

    def type_spec(_schema, _opts) do
      quote(do: number())
    end
  end
end
