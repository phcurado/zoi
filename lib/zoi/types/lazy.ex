defmodule Zoi.Types.Lazy do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fun]

  def new(fun, opts) when is_function(fun, 0) do
    opts
    |> Keyword.merge(fun: fun)
    |> apply_type()
  end

  def new({_mod, _func, _args} = mfa, opts) do
    opts
    |> Keyword.merge(fun: mfa)
    |> apply_type()
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Lazy{fun: {mod, func, args}}, value, opts) do
      schema = apply(mod, func, args)
      Zoi.parse(schema, value, opts)
    end

    def parse(%Zoi.Types.Lazy{fun: fun}, value, opts) do
      schema = fun.()
      Zoi.parse(schema, value, opts)
    end
  end

  # Lazy types return term() for type_spec to avoid infinite recursion
  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Lazy{}, _opts) do
      quote(do: term())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(%Zoi.Types.Lazy{fun: {mod, func, args}}) do
      schema = apply(mod, func, args)
      Zoi.JSONSchema.encode_schema(schema)
    end

    def encode(%Zoi.Types.Lazy{fun: fun}) do
      schema = fun.()
      Zoi.JSONSchema.encode_schema(schema)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(%Zoi.Types.Lazy{fun: {mod, func, args}}) do
      schema = apply(mod, func, args)
      Zoi.Describe.Encoder.encode(schema)
    end

    def encode(%Zoi.Types.Lazy{fun: fun}) do
      schema = fun.()
      Zoi.Describe.Encoder.encode(schema)
    end
  end
end
