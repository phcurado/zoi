defmodule Zoi.Types.Object do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :inner, :strict, :coerce]

  def new(fields, opts) when is_map(fields) do
    inner =
      Zoi.keyword(Map.to_list(fields), opts)
      |> Zoi.transform(fn map ->
        Enum.into(map, %{})
      end)

    apply_type(opts ++ [fields: fields, inner: inner])
  end

  def new(_fields, _opts) do
    raise ArgumentError, "object must receive a map"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{inner: inner}, input, opts) when is_map(input) do
      Zoi.parse(inner, Map.to_list(input), opts)
    end

    def parse(schema, _, _) do
      {:error, schema.meta.error || "invalid type: must be a map"}
    end
  end
end
