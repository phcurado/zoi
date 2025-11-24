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

    def type_spec(_schema, _opts) do
      quote(do: any())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end
end
