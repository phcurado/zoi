if Code.ensure_loaded?(Decimal) do
  defmodule Zoi.Types.Decimal do
    @moduledoc false

    use Zoi.Type.Def, fields: [coerce: false]

    def new(opts) do
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
        {:error, schema.meta.error || "invalid type: must be a decimal"}
      end
    end
  end
end
