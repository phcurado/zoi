defmodule Zoi.Types.Atom do
  @moduledoc false

  use Zoi.Type.Def

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_atom(input) do
      {:ok, input}
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:atom, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: atom())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:atom/0`"
  end
end
