defmodule Zoi.Types.Null do
  @moduledoc false

  use Zoi.Type.Def

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_nil(input) do
      {:ok, input}
    end

    def parse(schema, _input, _opts) do
      {:error, Zoi.Error.invalid_type(nil, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: nil)
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(_schema), do: %{type: :null}
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`nil`"
  end
end
