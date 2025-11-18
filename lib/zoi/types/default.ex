defmodule Zoi.Types.Default do
  @moduledoc false
  use Zoi.Type.Def, fields: [:inner, :value]

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(inner, value, opts \\ []) do
    opts
    |> Keyword.merge(inner: inner, value: value)
    |> apply_type()
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Default{value: default_value}, nil, _opts) do
      # Default value is short circuit, return without effects
      {:ok, default_value}
    end

    def parse(%Zoi.Types.Default{inner: schema}, value, opts) do
      Zoi.parse(schema, value, opts)
    end

    def type_spec(%Zoi.Types.Default{inner: schema}, opts) do
      Zoi.Type.type_spec(schema, opts)
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
