if Code.ensure_loaded?(Decimal) do
  defmodule Zoi.Types.Decimal do
    @moduledoc false

    use Zoi.Type.Def

    def new(opts) do
      apply_type(opts)
    end

    defimpl Zoi.Type do
      def parse(schema, input, _opts) do
        case Decimal.cast(input) do
          {:ok, decimal} -> {:ok, decimal}
          :error -> {:error, schema.meta.error || "invalid type: must be a decimal"}
        end
      end
    end
  end
end
