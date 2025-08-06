defmodule Zoi.Types.Integer do
  @moduledoc false

  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      cond do
        is_integer(input) ->
          {:ok, input}

        coerce and is_binary(input) ->
          coerce_integer(schema, input)

        true ->
          error(schema)
      end
    end

    defp coerce_integer(schema, input) do
      case Integer.parse(input) do
        {integer, ""} -> {:ok, integer}
        _error -> error(schema)
      end
    end

    defp error(schema) do
      {:error, schema.meta.error || "invalid type: must be an integer"}
    end
  end
end
