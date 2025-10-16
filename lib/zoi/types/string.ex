defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts) do
    opts = Keyword.merge([error: "invalid type: must be a string", coerce: false], opts)
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
          {:error, schema.meta.error}
      end
    end

    def type_spec(_schema, _opts) do
      quote(do: binary())
    end
  end
end

defimpl Inspect, for: Zoi.Types.String do
  def inspect(type, opts) do
    Zoi.Inspect.inspect_type(type, opts)
  end
end
