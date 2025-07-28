defmodule Zoi.Types.Optional do
  @type t :: %__MODULE__{inner: Zoi.Type.t()}
  defstruct [:inner]

  @spec new(inner :: Zoi.Type.t()) :: t()
  def new(inner) do
    struct!(__MODULE__, inner: inner)
  end

  def new(inner) do
    struct!(__MODULE__, inner: inner)
  end

  defimpl Zoi.Type do
    def parse(%{inner: _schema}, nil, _opts), do: {:ok, nil}
    def parse(%{inner: schema}, value, opts), do: Zoi.Type.parse(schema, value, opts)
  end
end
