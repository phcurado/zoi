defmodule Zoi.Types.Boolean do
  @moduledoc false

  use Zoi.Type.Def, fields: [coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
  end

  def new(opts \\ []) do
    opts = Keyword.merge([coerce: false], opts)
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_boolean(input) do
      {:ok, input}
    end

    def parse(schema, input, opts) when is_binary(input) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      if coerce and input in ["true", "false"] do
        {:ok, input == "true"}
      else
        error(schema)
      end
    end

    def parse(schema, _input, _opts) do
      error(schema)
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:boolean, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: boolean())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(_schema), do: %{type: :boolean}
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:boolean/0`"
  end
end
