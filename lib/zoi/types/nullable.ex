defmodule Zoi.Types.Nullable do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  def new(inner, opts \\ []) do
    opts =
      Keyword.merge([error: "#{inner.meta.error} or nil"], opts)

    apply_type(opts ++ [inner: Zoi.union([inner, Zoi.null()], opts)])
  end

  defimpl Zoi.Type do
    def parse(%{inner: schema}, value, opts), do: Zoi.parse(schema, value, opts)

    def type_spec(%{inner: schema}, opts) do
      inner_type = Zoi.Type.type_spec(schema, opts)

      quote do
        unquote(inner_type)
      end
    end
  end
end
