defmodule Zoi.Types.Boolean do
  @moduledoc false

  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      cond do
        is_boolean(input) ->
          {:ok, input}

        coerce ->
          coerce_boolean(schema, input)

        true ->
          error(schema)
      end
    end

    defp coerce_boolean(schema, input) do
      cond do
        input in ["true", "1", "yes", "on", "y", "enabled"] ->
          {:ok, true}

        input in ["false", "0", "no", "off", "n", "disabled"] ->
          {:ok, false}

        true ->
          error(schema)
      end
    end

    defp error(schema) do
      {:error, schema.meta.error || "invalid boolean type"}
    end
  end
end
