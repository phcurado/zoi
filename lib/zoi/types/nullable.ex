defmodule Zoi.Types.Nullable do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  def new(inner, opts \\ []) do
    apply_type(opts ++ [inner: inner])
  end

  defimpl Zoi.Type do
    def parse(%{inner: _schema}, nil, _opts), do: {:ok, nil}
    def parse(%{inner: schema}, value, opts), do: Zoi.parse(schema, value, opts)

    def type_spec(%{inner: schema}, opts) do
      inner_type = Zoi.Type.type_spec(schema, opts)

      quote do
        unquote(inner_type) | nil
      end
    end
  end
end
