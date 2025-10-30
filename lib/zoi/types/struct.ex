defmodule Zoi.Types.Struct do
  @moduledoc false

  use Zoi.Type.Def, fields: [:module, :fields, :keys, :inner, :strict, :coerce]

  def new(module, fields, opts) when is_map(fields) or is_list(fields) do
    fields =
      fields
      |> Enum.map(fn {key, type} ->
        if type.meta.required == nil do
          {key, Zoi.required(type)}
        else
          {key, type}
        end
      end)

    inner =
      fields
      |> Zoi.keyword(opts)
      |> Zoi.to_struct(module)

    keys = Enum.map(fields, fn {key, _type} -> key end)

    if Enum.any?(keys, &(!is_atom(&1))) do
      raise ArgumentError, "all keys in struct must be atoms"
    end

    opts =
      Keyword.merge([error: "invalid type: must be a struct", strict: false, coerce: false], opts)

    apply_type(opts ++ [module: module, fields: fields, keys: keys, inner: inner])
  end

  def new(_module, _fields, _opts) do
    raise ArgumentError, "struct must receive a map"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Struct{inner: inner, module: module}, %module{} = input, opts) do
      input =
        Map.from_struct(input)
        |> Map.to_list()

      Zoi.parse(inner, input, opts)
    end

    def parse(%Zoi.Types.Struct{inner: inner, coerce: true}, input, opts) when is_map(input) do
      Zoi.parse(inner, Map.to_list(input), opts)
    end

    def parse(schema, _, _) do
      {:error, schema.meta.error}
    end

    def type_spec(%Zoi.Types.Struct{module: module, fields: fields}, opts) do
      fields
      |> Enum.map(fn {key, type} ->
        {key, Zoi.Type.type_spec(type, opts), type}
      end)
      |> Enum.map(fn {key, type_spec, _type} ->
        quote do: {unquote(key), unquote(type_spec)}
      end)
      |> then(&quote(do: %unquote(module){unquote_splicing(&1)}))
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      fields_docs =
        case type.fields do
          fields when is_list(fields) ->
            container_doc("%{", fields, "}", %{limit: 10}, fn
              {key, schema}, _opts -> concat("#{key}: ", Zoi.Inspect.inspect_type(schema, opts))
            end)

          schema_type ->
            Zoi.Inspect.inspect_type(schema_type, opts)
        end

      opts = Map.put(opts, :extra_fields, fields: fields_docs, struct: type.module)

      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
