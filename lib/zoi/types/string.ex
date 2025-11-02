defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts) do
    opts = Keyword.merge([coerce: false], opts)
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      cond do
        is_binary(input) ->
          {:ok, input}

        coerce ->
          {:ok, to_string(input)}

        true ->
          {:error, error(schema)}
      end
    end

    defp error(schema) do
      Zoi.Error.invalid_type("string", custom_message: schema.meta.error)
    end

    def type_spec(_schema, _opts) do
      quote(do: binary())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
