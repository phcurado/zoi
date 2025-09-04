defmodule Zoi.ISO.NaiveDateTime do
  @moduledoc false
  use Zoi.Type.Def

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, _opts) when is_binary(input) do
      case NaiveDateTime.from_iso8601(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, _parsed} ->
          {:ok, input}
      end
    end

    def parse(schema, _input, _opts) do
      error(schema)
    end

    defp error(schema) do
      {:error, schema.meta.error || "invalid type: must be an ISO naive datetime"}
    end

    def type_spec(_schema, _opts) do
      quote(do: binary())
    end
  end
end
