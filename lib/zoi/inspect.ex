defmodule Zoi.Inspect do
  @moduledoc false

  import Inspect.Algebra

  @spec inspect_type(Zoi.Type.t(), Inspect.Opts.t(), keyword()) :: Inspect.Algebra.t()
  def inspect_type(type, inspect_opts, opts \\ [])

  def inspect_type(%Zoi.Types.Array{} = type, inspect_opts, opts),
    do: inspect_array(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Default{} = type, inspect_opts, opts),
    do: inspect_default(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Enum{} = type, inspect_opts, opts),
    do: inspect_enum(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Intersection{} = type, inspect_opts, opts),
    do: inspect_intersection(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Literal{} = type, inspect_opts, opts),
    do: inspect_literal(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Map{} = type, inspect_opts, opts),
    do: inspect_map(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Object{} = type, inspect_opts, opts),
    do: inspect_object(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Keyword{} = type, inspect_opts, opts),
    do: inspect_keyword(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.StringBoolean{} = type, inspect_opts, opts),
    do: inspect_string_boolean(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Struct{} = type, inspect_opts, opts),
    do: inspect_struct(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Tuple{} = type, inspect_opts, opts),
    do: inspect_tuple(type, inspect_opts, opts)

  def inspect_type(%Zoi.Types.Union{} = type, inspect_opts, opts),
    do: inspect_union(type, inspect_opts, opts)

  # Default to other types
  def inspect_type(type, inspect_opts, opts), do: do_inspect_type(type, inspect_opts, opts)

  defp do_inspect_type(type, inspect_opts, opts) do
    name = inspect_name(type)

    list =
      meta_field_list(type) ++ type_common_fields(type) ++ Keyword.get(opts, :extra_fields, [])

    container_doc("#Zoi.#{name}<", list, ">", %Inspect.Opts{limit: 8}, fn
      {key, {:doc_group, _, _} = doc}, _opts ->
        # tuple means it was already been converted to doc
        # this usually happens when parsing nested types
        concat("#{key}: ", doc)

      {key, value}, _opts ->
        if value == nil do
          empty()
        else
          concat("#{key}: ", to_doc(value, inspect_opts))
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

  defp inspect_array(type, inspect_opts, opts) do
    opts = add_extra(opts, inner: inspect_type(type.inner, inspect_opts))
    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_default(type, inspect_opts, opts) do
    opts = add_extra(opts, default: type.value)
    inspect_type(type.inner, inspect_opts, opts)
  end

  defp inspect_enum(type, inspect_opts, opts) do
    symetric_enum? = Enum.all?(type.values, fn {key, value} -> key == value end)

    opts =
      if symetric_enum? do
        # since key equals value, we can just show the values
        add_extra(opts,
          values: Enum.map(type.values, fn {_key, value} -> value end)
        )
      else
        add_extra(opts, values: type.values)
      end

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_intersection(type, inspect_opts, opts) do
    schemas_docs =
      container_doc("[", type.schemas, "]", %Inspect.Opts{limit: 5}, fn
        schema, _opts -> inspect_type(schema, inspect_opts)
      end)

    opts =
      add_extra(opts, schemas: schemas_docs)

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_literal(type, inspect_opts, opts) do
    opts =
      add_extra(opts, value: type.value)

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_map(type, inspect_opts, opts) do
    opts =
      add_extra(opts,
        key: inspect_type(type.key_type, inspect_opts),
        value: inspect_type(type.value_type, inspect_opts)
      )

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_object(type, inspect_opts, opts) do
    fields_docs =
      container_doc("%{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
        {key, schema}, _opts -> concat("#{key}: ", inspect_type(schema, inspect_opts))
      end)

    opts = add_extra(opts, fields: fields_docs)

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_keyword(type, inspect_opts, opts) do
    fields_docs =
      case type.fields do
        fields when is_list(fields) ->
          container_doc("[", fields, "]", %Inspect.Opts{limit: 10}, fn
            {key, schema}, _opts -> concat("#{key}: ", inspect_type(schema, inspect_opts))
          end)

        schema_type ->
          inspect_type(schema_type, inspect_opts)
      end

    opts = add_extra(opts, fields: fields_docs)

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_string_boolean(type, inspect_opts, opts) do
    extra_fields =
      Enum.map([:case, :truthy, :falsy], fn field ->
        {field, Map.get(type, field)}
      end)

    opts = add_extra(opts, extra_fields)
    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_struct(type, inspect_opts, opts) do
    fields_docs =
      container_doc("%{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
        {key, schema}, _opts -> concat("#{key}: ", inspect_type(schema, inspect_opts))
      end)

    opts = add_extra(opts, fields: fields_docs, module: type.module)

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_tuple(type, inspect_opts, opts) do
    fields_docs =
      container_doc("{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
        field, _opts -> inspect_type(field, inspect_opts)
      end)

    opts = add_extra(opts, fields: fields_docs)

    do_inspect_type(type, inspect_opts, opts)
  end

  defp inspect_union(type, inspect_opts, opts) do
    result =
      container_doc("[", type.schemas, "]", %Inspect.Opts{limit: 5}, fn
        schema, _opts -> inspect_type(schema, inspect_opts)
      end)

    opts =
      add_extra(opts, schemas: result)

    do_inspect_type(type, inspect_opts, opts)
  end

  defp add_extra(opts, opts_to_add) do
    Keyword.put(opts, :extra_fields, opts_to_add)
  end
end
