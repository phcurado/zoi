defmodule Zoi.Types.Atom do
  @moduledoc false
  use Zoi.Type.Def, fields: []

  def opts() do
    Zoi.Types.Keyword.new(
      [
        description: Zoi.Opts.description(),
        example: Zoi.Opts.example(),
        metadata: Zoi.Opts.metadata(),
        error: Zoi.Opts.error()
      ],
      []
    )
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

    def type_spec(_schema, _opts) do
      quote(do: atom())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
