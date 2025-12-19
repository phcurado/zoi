defmodule Zoi.Types.Any do
  @moduledoc false
  use Zoi.Type.Def

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Any{}, value, _opts), do: {:ok, value}
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: any())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:term/0`"
  end
end
