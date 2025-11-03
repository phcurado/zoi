defmodule Zoi.Types.Time do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    opts = Keyword.merge([coerce: false], opts)
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, %Time{} = input, _opts) do
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
      case Time.from_iso8601(input) do
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
      {:error, Zoi.Error.invalid_type(:time, custom_message: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: Time.t())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
