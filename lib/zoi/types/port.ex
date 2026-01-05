defmodule Zoi.Types.Port do
  @moduledoc false

  use Zoi.Type.Def

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_port(input) do
      {:ok, input}
    end

    def parse(schema, _input, _opts) do
      error(schema)
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:port, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: port())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:port/0`"
  end
end
