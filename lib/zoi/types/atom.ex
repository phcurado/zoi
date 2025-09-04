defmodule Zoi.Types.Atom do
  @moduledoc false
  use Zoi.Type.Def, fields: []

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_atom(input) do
      {:ok, input}
    end

    def parse(schema, _input, _opts) do
      {:error, schema.meta.error || "invalid type: must be an atom"}
    end

    def type_spec(_schema, _opts) do
      quote(do: atom())
    end
  end
end
