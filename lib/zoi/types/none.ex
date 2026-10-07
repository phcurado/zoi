defmodule Zoi.Types.None do
  @moduledoc false
  use Zoi.Type.Def

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, _input, _opts) do
      {:error, Zoi.Error.invalid_type(:none, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: none())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(_schema) do
      false
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema) do
      "`t:none/0`"
    end
  end
end
