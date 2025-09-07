defmodule Zoi.Types.Required do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  def new(inner, opts \\ []) do
    apply_type(opts ++ [inner: inner])
  end

  defimpl Zoi.Type do
    def parse(%{inner: schema}, value, opts) do
      Zoi.parse(schema, value, opts)
    end

    def type_spec(%{inner: schema}, opts) do
      Zoi.Type.type_spec(schema, opts)
    end
  end
end
