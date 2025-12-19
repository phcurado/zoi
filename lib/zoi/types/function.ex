defmodule Zoi.Types.Function do
  @moduledoc false

  use Zoi.Type.Def, fields: [:arity]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Types.Extend.new(arity: Zoi.Types.Integer.new(gte: 0, description: "Function arity"))
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, _opts) when is_function(input) do
      case schema.arity do
        nil -> {:ok, input}
        arity when is_function(input, arity) -> {:ok, input}
        arity -> error_with_arity(schema, arity)
      end
    end

    def parse(schema, _input, _opts) do
      case schema.arity do
        nil -> error(schema)
        arity -> error_with_arity(schema, arity)
      end
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:function, error: schema.meta.error)}
    end

    defp error_with_arity(schema, arity) do
      {:error,
       Zoi.Error.invalid_type(:function,
         issue: "invalid type: expected function of arity #{arity}",
         error: schema.meta.error
       )}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts), do: quote(do: function())
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts, arity: type.arity)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:function/0`"
  end
end
