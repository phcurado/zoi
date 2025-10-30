defmodule Zoi.Types.Null do
  @moduledoc false

  use Zoi.Type.Def

  def new(opts \\ []) do
    opts = Keyword.merge([error: "invalid type: must be nil"], opts)
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_nil(input) do
      {:ok, input}
    end

    def parse(schema, _input, _opts) do
      {:error, schema.meta.error}
    end

    def type_spec(_schema, _opts) do
      quote(do: nil)
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
