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

    def type_spec(%Zoi.Types.Object{fields: fields}, opts) do
      fields
      |> Enum.map(fn {key, type} ->
        {key, Zoi.Type.type_spec(type, opts), type}
      end)
      |> Enum.map(fn {key, type_spec, type} ->
        case type do
          %Zoi.Types.Optional{} -> quote do: {optional(unquote(key)), unquote(type_spec)}
          _ -> quote do: {required(unquote(key)), unquote(type_spec)}
        end
      end)
      |> then(&quote(do: %{unquote_splicing(&1)}))
    end
  end
end
