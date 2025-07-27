defmodule Zoi.Types.Optional do
  defstruct inner: nil

  def new(inner) do
    struct!(__MODULE__, inner: inner)
  end
end

defimpl Zoi.Type, for: Zoi.Types.Optional do
  def parse(%{inner: _schema}, nil, _opts), do: {:ok, nil}
  def parse(%{inner: schema}, value, opts), do: Zoi.Type.parse(schema, value, opts)
end
