defmodule Zoi.Types.DateTime do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    opts = Keyword.merge([coerce: false], opts)
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, %DateTime{} = input, _opts) do
      {:ok, input}
    end

    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      case coerce do
        true -> coerce(schema, input)
        _false -> error(schema)
      end
    end

    defp coerce(schema, input) when is_binary(input) do
      case DateTime.from_iso8601(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, parsed, _offset} ->
          {:ok, parsed}
      end
    end

    defp coerce(schema, input) when is_integer(input) do
      case DateTime.from_unix(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, parsed} ->
          {:ok, parsed}
      end
    end

    defp coerce(schema, _input) do
      error(schema)
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:datetime, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: DateTime.t())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
