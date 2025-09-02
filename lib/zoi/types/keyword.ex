defmodule Zoi.Types.Keyword do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner, :strict]

  def new(fields, opts) when is_list(fields) do
    inner =
      Zoi.object(Map.new(fields), opts)
      |> Zoi.transform(fn map ->
        Enum.to_list(map)
      end)

    apply_type(opts ++ [inner: inner])
  end

  def new(_fields, _opts) do
    raise ArgumentError, "keyword must receive a keyword list"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Keyword{inner: inner}, input, opts) when is_list(input) do
      Zoi.parse(inner, Map.new(input), opts)
    end

    def parse(schema, _, _) do
      {:error, schema.meta.error || "invalid type: must be a keyword list"}
    end
  end
end
