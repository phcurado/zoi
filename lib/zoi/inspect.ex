defmodule Zoi.Inspect do
  @moduledoc false

  import Inspect.Algebra

  def inspect_type(%Zoi.Types.Array{} = type, opts) do
    opts = Map.put(opts, :extra_fields, inner: inspect_type(type.inner, opts))
    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Default{} = type, opts) do
    opts = Map.put(opts, :extra_fields, default: type.value)
    do_inspect_type(type.inner, opts)
  end

  def inspect_type(%Zoi.Types.Enum{} = type, opts) do
    symetric_enum? = Enum.all?(type.values, fn {key, value} -> key == value end)

    opts =
      if symetric_enum? do
        # since key equals value, we can just show the values
        Map.put(opts, :extra_fields, values: Enum.map(type.values, fn {_key, value} -> value end))
      else
        Map.put(opts, :extra_fields, values: type.values)
      end

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Intersection{} = type, opts) do
    schemas_docs =
      container_doc("[", type.schemas, "]", %Inspect.Opts{limit: 5}, fn
        schema, _opts -> inspect_type(schema, opts)
      end)

    opts =
      Map.put(opts, :extra_fields, schemas: schemas_docs)

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Literal{} = type, opts) do
    opts =
      Map.put(opts, :extra_fields, value: type.value)

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Map{} = type, opts) do
    opts =
      Map.put(
        opts,
        :extra_fields,
        key: Zoi.Inspect.inspect_type(type.key_type, opts),
        value: Zoi.Inspect.inspect_type(type.value_type, opts)
      )

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Object{} = type, opts) do
    fields_docs =
      container_doc("%{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
        {key, schema}, _opts -> concat("#{key}: ", inspect_type(schema, opts))
      end)

    opts = Map.put(opts, :extra_fields, fields: fields_docs)

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Keyword{} = type, opts) do
    fields_docs =
      case type.fields do
        fields when is_list(fields) ->
          container_doc("[", fields, "]", %Inspect.Opts{limit: 10}, fn
            {key, schema}, _opts -> concat("#{key}: ", inspect_type(schema, opts))
          end)

        schema_type ->
          inspect_type(schema_type, opts)
      end

    opts = Map.put(opts, :extra_fields, fields: fields_docs)

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.StringBoolean{} = type, opts) do
    extra_fields =
      Enum.map([:case, :truthy, :falsy], fn field ->
        {field, Map.get(type, field)}
      end)

    opts = Map.put(opts, :extra_fields, extra_fields)
    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Struct{} = type, opts) do
    fields_docs =
      container_doc("%{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
        {key, schema}, _opts -> concat("#{key}: ", inspect_type(schema, opts))
      end)

    opts = Map.put(opts, :extra_fields, fields: fields_docs, module: type.module)

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Tuple{} = type, opts) do
    fields_docs =
      container_doc("{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
        field, _opts ->
          inspect_type(field, opts)
      end)

    opts = Map.put(opts, :extra_fields, fields: fields_docs)

    do_inspect_type(type, opts)
  end

  def inspect_type(%Zoi.Types.Union{} = type, opts) do
    result =
      container_doc("[", type.schemas, "]", %Inspect.Opts{limit: 5}, fn
        schema, _opts -> inspect_type(schema, opts)
      end)

    opts =
      Map.put(opts, :extra_fields, schemas: result)

    do_inspect_type(type, opts)
  end

  def inspect_type(type, opts) do
    # Default to other types
    do_inspect_type(type, opts)
  end

  defp do_inspect_type(type, opts) do
    name = inspect_name(type)

    list = meta_field_list(type) ++ type_common_fields(type) ++ Map.get(opts, :extra_fields, [])

    container_doc("#Zoi.#{name}<", list, ">", %Inspect.Opts{limit: 8}, fn
      {key, {:doc_group, _, _} = doc}, _opts ->
        # tuple means it was already been converted to doc
        # this usually happens when parsing nested types
        concat("#{key}: ", doc)

      {key, value}, _opts ->
        if value == nil do
          empty()
        else
          concat("#{key}: ", to_doc(value, opts))
        end
    end)
  end

  defp meta_field_list(type) do
    Enum.map([:required, :description], &{&1, Map.get(type.meta, &1)})
  end

  defp type_common_fields(type) do
    Enum.map([:coerce, :strict], &{&1, Map.get(type, &1)})
  end

  defp inspect_name(type) do
    modules = type.__struct__ |> Module.split()

    case modules do
      ["Zoi", "ISO", name] -> "ISO." <> Macro.underscore(name)
      list -> List.last(list) |> Macro.underscore()
    end
  end
end
