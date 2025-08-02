defmodule Zoi.Types.Integer do
  @moduledoc false

  use Zoi.Type, fields: [coerce: false]

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
      {:error, "invalid integer type"}
    end
  end
end
