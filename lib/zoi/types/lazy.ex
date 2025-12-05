defmodule Zoi.Types.Lazy do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fun]

  def new(fun, opts \\ []) when is_function(fun, 0) do
    opts
    |> Keyword.merge(fun: fun)
    |> apply_type()
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Lazy{fun: fun}, value, opts) do
      schema = fun.()
      Zoi.parse(schema, value, opts)
    end

    # Lazy types return term() for type_spec to avoid infinite recursion
    # in recursive schemas. The actual type cannot be expressed in Elixir's
    # type system for self-referential structures.
    def type_spec(%Zoi.Types.Lazy{}, _opts) do
      quote(do: term())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(%Zoi.Types.Lazy{fun: fun}) do
      schema = fun.()
      Zoi.JSONSchema.Encoder.encode(schema)
    end
  end
end
