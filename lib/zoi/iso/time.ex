defmodule Zoi.ISO.Time do
  @moduledoc false
  use Zoi.Type.Def

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, _opts) when is_binary(input) do
      case Time.from_iso8601(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, _date} ->
          {:ok, input}
      end
    end

    def parse(schema, _input, _opts) do
      error(schema)
    end

    defp error(schema) do
      {:error,
       Zoi.Error.invalid_type(:iso_time,
         issue: "invalid type: expected ISO time",
         custom_message: schema.meta.error
       )}
    end

    def type_spec(_schema, _opts) do
      quote(do: binary())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
