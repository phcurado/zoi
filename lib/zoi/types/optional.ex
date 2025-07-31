defmodule Zoi.Types.Optional do
  @moduledoc false

  @type t :: %__MODULE__{inner: Zoi.Type.t(), meta: Zoi.Types.Meta.t()}
  defstruct [:inner, :meta]

  @spec new(inner :: Zoi.Type.t(), opts :: Zoi.options()) :: t()
  def new(inner, opts \\ []) do
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)
    opts = Keyword.merge(opts, inner: inner, meta: meta)
    struct!(__MODULE__, opts)
  end

  defimpl Zoi.Type do
    def parse(%{inner: _schema}, nil, _opts), do: {:ok, nil}
    def parse(%{inner: schema}, value, opts), do: Zoi.parse(schema, value, opts)
  end
end
