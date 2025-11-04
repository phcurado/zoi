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
      Keyword.merge([strict: false, coerce: false], opts)

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
      {:error, Zoi.Error.invalid_type(:struct, error: schema.meta.error)}
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
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
