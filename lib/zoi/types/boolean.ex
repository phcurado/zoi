defmodule Zoi.Types.Boolean do
  @moduledoc false

  use Zoi.Type.Def, fields: [coerce: false]

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_boolean(input) do
      {:ok, input}
    end

    def parse(schema, input, opts) when is_binary(input) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      cond do
        coerce and input in ["true", "false"] ->
          {:ok, input == "true"}

        true ->
          error(schema)
      end
    end

    def parse(schema, _input, _opts) do
      error(schema)
    end

    defp error(schema) do
      {:error, schema.meta.error || "invalid type: must be a boolean"}
    end
  end
end
