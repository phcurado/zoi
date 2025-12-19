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
  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Default{inner: schema}, opts) do
      Zoi.TypeSpec.spec(schema, opts)
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      # Default shows the inner type with a default field added
      Zoi.Inspect.build(type.inner, opts, default: type.value)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(%Zoi.Types.Default{inner: inner, value: default_value}) do
      inner
      |> Zoi.JSONSchema.Encoder.encode()
      |> Map.put(:default, default_value)
    end
  end
end
