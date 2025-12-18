defmodule Zoi.Types.Atom do
  @moduledoc false

  use Zoi.Type.Def, fields: [coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_atom(input) do
      {:ok, input}
    end

    def parse(schema, input, opts) when is_binary(input) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      if coerce do
        {:ok, String.to_existing_atom(input)}
      else
        error(schema)
      end
    end

    def parse(schema, _, _) do
      error(schema)
    end

    def error(schema) do
      {:error, Zoi.Error.invalid_type(:atom, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: atom())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end
end
