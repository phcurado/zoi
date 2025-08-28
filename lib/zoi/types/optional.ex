defmodule Zoi.Types.Optional do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  def new(inner, opts \\ []) do
    apply_type(opts ++ [inner: inner])
  end

  defimpl Zoi.Type do
    def parse(%{inner: schema}, value, opts) do
      Zoi.parse(schema, value, opts)
    end
  end
end
