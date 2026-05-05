defmodule Zoi.JSONSchema.Decoder do
  @moduledoc """
  Decodes a JSON Schema map into a `Zoi` schema.

  The input is expected to be a JSON-shaped map with string keys (as
  produced by `Jason.decode!/1`, `:json.decode/1`, or any other JSON
  parser). The output is built from the same constructors used everywhere
  else (`Zoi.string/1`, `Zoi.map/2`, `Zoi.array/2`, ...).

  Use the public entry point `Zoi.from_json_schema/1`.

  ## Supported keywords

  Type keywords: `type` (`"string"`, `"integer"`, `"number"`, `"boolean"`,
  `"null"`, `"object"`, `"array"`), `const`, `enum`, `oneOf`, `anyOf`,
  `allOf`.

  Annotation keywords: `description`, `example`, `deprecated`, `title`,
  `examples`, `readOnly`, `writeOnly`, `$id`, `$comment`, `default`.

  Validation keywords:

    * String — `minLength`, `maxLength`, `pattern`, `format`
      (`"date"`, `"time"`, `"date-time"`, `"email"`, `"uri"`, `"uuid"`).
    * Numeric — `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`,
      `multipleOf`.
    * Array — `items`, `prefixItems`, `minItems`, `maxItems`.
    * Object — `properties`, `required`, `additionalProperties`.

  ## Limitations

  Keywords without a Zoi equivalent are dropped silently rather than
  raising. This includes `if`/`then`/`else`, `not`, `dependentRequired`,
  `patternProperties`, `propertyNames`, `contains`, `$ref`, and `$defs`.
  They are tracked in `TODO.md`.

  `oneOf` is decoded to `Zoi.union/2` and so loses the JSON Schema
  *exactly-one* matching semantics; the resulting schema accepts a value
  that matches *any* branch (`anyOf` semantics).
  """

  @bag_keys [
    {"title", :title},
    {"examples", :examples},
    {"readOnly", :read_only},
    {"writeOnly", :write_only},
    {"$id", :id},
    {"$comment", :comment}
  ]

  @doc """
  Decodes a JSON Schema map into a Zoi schema.

  Raises `ArgumentError` if the input is not a map.
  """
  @spec decode(map()) :: Zoi.schema()
  def decode(json_schema) when is_map(json_schema), do: convert(json_schema)

  def decode(other) do
    raise ArgumentError, "expected a JSON Schema map, got: #{inspect(other)}"
  end

  defp convert(schema) do
    schema
    |> base_schema()
    |> apply_metadata(schema)
  end

  defp base_schema(%{"oneOf" => schemas}) when is_list(schemas) do
    Zoi.union(Enum.map(schemas, &convert/1))
  end

  defp base_schema(%{"anyOf" => schemas}) when is_list(schemas) do
    Zoi.union(Enum.map(schemas, &convert/1))
  end

  defp base_schema(%{"allOf" => schemas}) when is_list(schemas) do
    Zoi.intersection(Enum.map(schemas, &convert/1))
  end

  defp base_schema(%{"const" => value}), do: Zoi.literal(value)

  defp base_schema(%{"enum" => values}) when is_list(values) do
    Zoi.enum(values)
  end

  defp base_schema(%{"type" => "string"} = schema), do: string_schema(schema)
  defp base_schema(%{"type" => "integer"} = schema), do: integer_schema(schema)
  defp base_schema(%{"type" => "number"} = schema), do: number_schema(schema)
  defp base_schema(%{"type" => "boolean"}), do: Zoi.boolean()
  defp base_schema(%{"type" => "null"}), do: Zoi.null()
  defp base_schema(%{"type" => "array"} = schema), do: array_schema(schema)
  defp base_schema(%{"type" => "object"} = schema), do: object_schema(schema)

  defp base_schema(%{"type" => types} = schema) when is_list(types) do
    Zoi.union(Enum.map(types, fn t -> base_schema(Map.put(schema, "type", t)) end))
  end

  defp base_schema(schema) when is_map(schema) do
    cond do
      Map.has_key?(schema, "properties") ->
        object_schema(Map.put(schema, "type", "object"))

      Map.has_key?(schema, "items") or Map.has_key?(schema, "prefixItems") ->
        array_schema(Map.put(schema, "type", "array"))

      true ->
        Zoi.any()
    end
  end

  defp string_schema(schema) do
    base =
      case Map.get(schema, "format") do
        "date" -> Zoi.date(coerce: true)
        "time" -> Zoi.time(coerce: true)
        "date-time" -> Zoi.datetime(coerce: true)
        "email" -> Zoi.email()
        "uri" -> Zoi.url()
        "uuid" -> Zoi.uuid()
        _ -> Zoi.string()
      end

    base
    |> maybe_apply(schema, "minLength", &Zoi.min/2)
    |> maybe_apply(schema, "maxLength", &Zoi.max/2)
    |> maybe_apply(schema, "pattern", &apply_pattern/2)
  end

  defp apply_pattern(schema, pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Zoi.regex(schema, regex)
      {:error, _} -> schema
    end
  end

  defp integer_schema(schema), do: apply_numeric_constraints(Zoi.integer(), schema)
  defp number_schema(schema), do: apply_numeric_constraints(Zoi.number(), schema)

  defp apply_numeric_constraints(schema, json) do
    schema
    |> maybe_apply(json, "minimum", &Zoi.gte/2)
    |> maybe_apply(json, "maximum", &Zoi.lte/2)
    |> maybe_apply(json, "exclusiveMinimum", &Zoi.gt/2)
    |> maybe_apply(json, "exclusiveMaximum", &Zoi.lt/2)
    |> maybe_apply(json, "multipleOf", &Zoi.multiple_of/2)
  end

  defp array_schema(%{"prefixItems" => items} = schema) when is_list(items) do
    tuple_fields = items |> Enum.map(&convert/1) |> List.to_tuple()
    apply_array_constraints(Zoi.tuple(tuple_fields), schema)
  end

  defp array_schema(%{"items" => items} = schema) when is_map(items) do
    apply_array_constraints(Zoi.array(convert(items)), schema)
  end

  defp array_schema(schema) do
    apply_array_constraints(Zoi.array(), schema)
  end

  defp apply_array_constraints(schema, json) do
    schema
    |> maybe_apply(json, "minItems", &Zoi.min/2)
    |> maybe_apply(json, "maxItems", &Zoi.max/2)
  end

  defp object_schema(schema) do
    properties = Map.get(schema, "properties", %{})
    required = schema |> Map.get("required", []) |> MapSet.new()
    additional = Map.get(schema, "additionalProperties")

    fields =
      Enum.map(properties, fn {key, prop_schema} ->
        prop_zoi = convert(prop_schema)

        prop_zoi =
          if MapSet.member?(required, key) do
            prop_zoi
          else
            Zoi.optional(prop_zoi)
          end

        {key, prop_zoi}
      end)

    map_opts = if additional == false, do: [unrecognized_keys: :error], else: []

    cond do
      fields == [] and is_map(additional) ->
        Zoi.map(Zoi.string(), convert(additional))

      fields == [] and map_opts == [] ->
        Zoi.map()

      true ->
        Zoi.map(Map.new(fields), map_opts)
    end
  end

  defp apply_metadata(schema, json) do
    schema
    |> apply_first_class(json)
    |> apply_bag(json)
    |> apply_default(json)
  end

  defp apply_first_class(schema, json) do
    schema =
      case Map.get(json, "description") do
        nil -> schema
        value -> put_meta(schema, :description, value)
      end

    schema =
      case Map.get(json, "example") do
        nil -> schema
        value -> put_meta(schema, :example, value)
      end

    case Map.get(json, "deprecated") do
      true -> put_meta(schema, :deprecated, "deprecated")
      _ -> schema
    end
  end

  defp apply_bag(schema, json) do
    pairs =
      Enum.flat_map(@bag_keys, fn {json_key, meta_key} ->
        case Map.get(json, json_key) do
          nil -> []
          false when meta_key in [:read_only, :write_only] -> []
          value -> [{meta_key, value}]
        end
      end)

    if pairs == [] do
      schema
    else
      existing = schema.meta.metadata || []
      put_meta(schema, :metadata, Keyword.merge(existing, pairs))
    end
  end

  defp apply_default(schema, json) do
    if Map.has_key?(json, "default") do
      Zoi.default(schema, Map.get(json, "default"))
    else
      schema
    end
  end

  defp put_meta(schema, key, value) do
    %{schema | meta: %{schema.meta | key => value}}
  end

  defp maybe_apply(schema, json, key, fun) do
    case Map.get(json, key) do
      nil -> schema
      value -> fun.(schema, value)
    end
  end
end
