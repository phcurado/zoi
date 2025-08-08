defmodule Zoi.ISO.DateTime do
  @moduledoc false
  use Zoi.Type.Def

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, _opts) when is_binary(input) do
      case DateTime.from_iso8601(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, _parsed, _offset} ->
          {:ok, input}
      end
    end

    def parse(schema, _input, _opts) do
      error(schema)
    end

    defp error(schema) do
      {:error, schema.meta.error || "invalid type: must be an ISO datetime"}
    end
  end
end
