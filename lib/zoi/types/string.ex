defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def opts() do
    Zoi.Types.Keyword.new(Zoi.Opts.shared_metadata(), strict: true)
  end

  def new(opts) do
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
          error(schema)
      end
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:string, error: schema.meta.error)}
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
