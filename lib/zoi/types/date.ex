defmodule Zoi.Types.Date do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, %Date{} = input, _opts) do
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
      case Date.from_iso8601(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, parsed} ->
          {:ok, parsed}
      end
    end

    defp coerce(_schema, input) when is_integer(input) do
      {:ok, Date.from_gregorian_days(input)}
    end

    defp coerce(schema, _input) do
      error(schema)
    end

    defp error(schema) do
      {:error, schema.meta.error || "invalid type: must be a date"}
    end

    def type_spec(_schema, _opts) do
      quote(do: Date.t())
    end
  end
end
