if Code.ensure_loaded?(Decimal) do
  defmodule Zoi.Types.Decimal do
    @moduledoc false

    use Zoi.Type.Def, fields: [coerce: true]

    def new(opts) do
      apply_type(opts)
    end

    defimpl Zoi.Type do
      def parse(schema, input, opts) do
        coerce = Keyword.get(opts, :coerce, schema.coerce)

        case Decimal.cast(input) do
          {:ok, decimal} ->
            if coerce do
              {:ok, decimal}
            else
              {:ok, input}
            end

          :error ->
            {:error, schema.meta.error || "invalid type: must be a decimal"}
        end
      end
    end
  end
end
