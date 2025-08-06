defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
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
          {:error, schema.meta.error || "invalid type: must be a string"}
      end
    end
  end
end
