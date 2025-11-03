defmodule Zoi.Types.Number do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    opts = Keyword.merge([coerce: false], opts)
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
          {:error, error(schema)}
      end
    end

    defp coerce_number(schema, input) do
      case Integer.parse(input) do
        {number, ""} ->
          {:ok, number}

        {_number, _rest} ->
          case Float.parse(input) do
            {float, ""} -> {:ok, float}
            _error -> {:error, error(schema)}
          end

        _error ->
          {:error, error(schema)}
      end
    end

    defp error(schema) do
      Zoi.Error.invalid_type("number", custom_message: schema.meta.error)
    end

    def type_spec(_schema, _opts) do
      quote(do: number())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
