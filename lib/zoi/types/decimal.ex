if Code.ensure_loaded?(Decimal) do
  defmodule Zoi.Types.Decimal do
    @moduledoc false

    use Zoi.Type.Def, fields: [coerce: false]

    def opts() do
      Zoi.Types.Keyword.new(Zoi.Opts.shared_metadata(), [])
    end

    def new(opts) do
      opts = Keyword.merge([coerce: false], opts)
      apply_type(opts)
    end

    defimpl Zoi.Type do
      import Decimal, only: [is_decimal: 1]

      def parse(schema, input, opts) do
        coerce = Keyword.get(opts, :coerce, schema.coerce)

        cond do
          is_decimal(input) ->
            {:ok, input}

          coerce == true ->
            case Decimal.cast(input) do
              {:ok, decimal} -> {:ok, decimal}
              :error -> error(schema)
            end

          true ->
            error(schema)
        end
      end

      defp error(schema) do
        {:error, Zoi.Error.invalid_type(:decimal, error: schema.meta.error)}
      end

      def type_spec(_schema, _opts) do
        quote(do: Decimal.t())
      end
    end

    defimpl Inspect do
      def inspect(type, opts) do
        Zoi.Inspect.inspect_type(type, opts)
      end
    end
  end
end
