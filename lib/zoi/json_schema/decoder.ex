defmodule Zoi.JSONSchema.Decoder do
  @moduledoc false

  @validation_keys ~w(
    minLength maxLength pattern format
    minimum maximum exclusiveMinimum exclusiveMaximum multipleOf
    properties required additionalProperties minProperties maxProperties propertyNames patternProperties
    items prefixItems minItems maxItems uniqueItems contains
  )

  @metadata_keys [
    {"title", :title},
    {"examples", :examples},
    {"readOnly", :read_only},
    {"writeOnly", :write_only},
    {"$id", :id},
    {"$comment", :comment},
    {"contentEncoding", :content_encoding},
    {"contentMediaType", :content_media_type}
  ]

  @spec decode(map() | boolean()) :: Zoi.schema()
  def decode(json_schema) when is_map(json_schema) or is_boolean(json_schema) do
    decode_schema(json_schema)
  end

  def decode(other) do
    raise ArgumentError, "expected a JSON Schema map or boolean, got: #{inspect(other)}"
  end

  defp decode_schema(true) do
    Zoi.any()
  end

  defp decode_schema(false) do
    Zoi.none()
  end

  defp decode_schema(schema) do
    schema
    |> base_schema()
    |> List.wrap()
    |> add_constraint(schema, "const", &Zoi.literal/1)
    |> add_constraint(schema, "enum", &Zoi.enum/1)
    |> add_constraint(schema, "anyOf", fn schemas -> decode_union(schemas, &Zoi.union/1) end)
    |> add_constraint(schema, "oneOf", fn schemas ->
      decode_union(schemas, &Zoi.exclusive_union/1)
    end)
    |> add_constraint(schema, "allOf", &decode_intersection/1)
    |> Enum.reverse()
    |> intersection_schema()
    |> apply_metadata(schema)
  end

  defp add_constraint(schemas, json, key, decoder) do
    case Map.fetch(json, key) do
      {:ok, value} -> [decoder.(value) | schemas]
      :error -> schemas
    end
  end

  defp decode_union(schemas, constructor) do
    schemas |> Enum.map(&decode_schema/1) |> union_schema(constructor)
  end

  defp union_schema([schema], _constructor) do
    schema
  end

  defp union_schema(schemas, constructor) do
    constructor.(schemas)
  end

  defp decode_intersection(schemas) do
    schemas |> Enum.map(&decode_schema/1) |> intersection_schema()
  end

  defp intersection_schema([]) do
    Zoi.any()
  end

  defp intersection_schema([schema]) do
    schema
  end

  defp intersection_schema(schemas) do
    Zoi.intersection(schemas)
  end

  defp base_schema(%{"type" => "string"} = schema), do: string_schema(schema)
  defp base_schema(%{"type" => "integer"} = schema), do: integer_schema(schema)
  defp base_schema(%{"type" => "number"} = schema), do: number_schema(schema)
  defp base_schema(%{"type" => "boolean"}), do: Zoi.boolean()
  defp base_schema(%{"type" => "null"}), do: Zoi.null()
  defp base_schema(%{"type" => "array"} = schema), do: array_schema(schema)
  defp base_schema(%{"type" => "object"} = schema), do: object_schema(schema)

  defp base_schema(%{"type" => types} = schema) when is_list(types) do
    types
    |> Enum.map(fn type -> base_schema(Map.put(schema, "type", type)) end)
    |> union_schema(&Zoi.union/1)
  end

  defp base_schema(schema) when is_map(schema) do
    if Enum.any?(@validation_keys, &Map.has_key?(schema, &1)) do
      ~w(string number boolean null array object)
      |> Enum.map(fn type -> base_schema(Map.put(schema, "type", type)) end)
      |> Zoi.union()
    else
      nil
    end
  end

  defp string_schema(schema) do
    base =
      case Map.get(schema, "format") do
        "date" -> Zoi.ISO.date()
        "time" -> Zoi.ISO.time()
        "date-time" -> Zoi.ISO.datetime()
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

  defp integer_schema(schema) do
    Zoi.number(error: "invalid type: expected integer")
    |> apply_numeric_constraints(schema)
    |> Zoi.refine({Zoi.Validations, :validate_integer, []})
  end

  defp number_schema(schema), do: apply_numeric_constraints(Zoi.number(), schema)

  defp apply_numeric_constraints(schema, json) do
    schema
    |> maybe_apply(json, "minimum", &Zoi.gte/2)
    |> maybe_apply(json, "maximum", &Zoi.lte/2)
    |> maybe_apply(json, "exclusiveMinimum", &Zoi.gt/2)
    |> maybe_apply(json, "exclusiveMaximum", &Zoi.lt/2)
    |> maybe_apply(json, "multipleOf", &Zoi.multiple_of/2)
  end

  defp array_schema(schema) do
    prefix_items = schema |> Map.get("prefixItems", []) |> Enum.map(&decode_schema/1)

    schema
    |> array_items_schema()
    |> Zoi.array()
    |> Map.put(:prefix_items, prefix_items)
    |> apply_array_constraints(schema)
  end

  defp array_items_schema(%{"items" => items}) when is_map(items) or is_boolean(items) do
    decode_schema(items)
  end

  defp array_items_schema(_) do
    Zoi.any()
  end

  defp apply_array_constraints(schema, json) do
    schema
    |> maybe_apply(json, "minItems", &Zoi.min/2)
    |> maybe_apply(json, "maxItems", &Zoi.max/2)
    |> maybe_apply_unique(json)
    |> maybe_apply_contains(json)
  end

  defp maybe_apply_unique(schema, %{"uniqueItems" => true}) do
    Zoi.Validations.Unique.set(schema, true, [])
  end

  defp maybe_apply_unique(schema, _), do: schema

  defp maybe_apply_contains(schema, %{"contains" => contains} = json) do
    opts = [min: Map.get(json, "minContains", 1), max: Map.get(json, "maxContains")]
    Zoi.contains(schema, decode_schema(contains), opts)
  end

  defp maybe_apply_contains(schema, _) do
    schema
  end

  defp object_schema(schema) do
    properties = Map.get(schema, "properties", %{})
    required = Map.get(schema, "required", [])
    additional = Map.get(schema, "additionalProperties")
    unrecognized_keys = unrecognized_keys(additional)

    properties
    |> Map.new(fn {key, prop_schema} ->
      {key, prop_schema |> decode_schema() |> maybe_optional(key, required)}
    end)
    |> Zoi.map(unrecognized_keys: unrecognized_keys)
    |> apply_pattern_properties(schema)
    |> add_required_fields(required)
    |> maybe_apply(schema, "minProperties", &Zoi.min/2)
    |> maybe_apply(schema, "maxProperties", &Zoi.max/2)
    |> maybe_apply(schema, "propertyNames", &apply_property_names/2)
  end

  defp apply_pattern_properties(schema, %{"patternProperties" => properties}) do
    patterns =
      Enum.map(properties, fn {pattern, value} ->
        {Regex.compile!(pattern), decode_schema(value)}
      end)

    %{schema | pattern_properties: patterns}
  end

  defp apply_pattern_properties(schema, _json) do
    schema
  end

  defp apply_property_names(schema, property_names) when is_boolean(property_names) do
    %{schema | key_type: decode_schema(property_names)}
  end

  defp apply_property_names(schema, property_names) do
    key_type =
      property_names
      |> Map.put_new("type", "string")
      |> decode_schema()

    %{schema | key_type: key_type}
  end

  defp maybe_optional(schema, key, required) do
    if key in required do
      schema
    else
      Zoi.optional(schema)
    end
  end

  defp add_required_fields(schema, required) do
    Enum.reduce(required, schema, fn key, schema ->
      if List.keymember?(schema.fields, key, 0) do
        schema
      else
        field_schema =
          case Zoi.Types.Map.pattern_schemas(schema.pattern_properties, key) do
            [] -> required_property_schema(schema.unrecognized_keys)
            _schemas -> Zoi.any()
          end

        %{schema | fields: [{key, Zoi.required(field_schema)} | schema.fields]}
      end
    end)
  end

  defp required_property_schema({:preserve, {_, schema}}) do
    schema
  end

  defp required_property_schema(:error) do
    Zoi.none()
  end

  defp required_property_schema(_unrecognized_keys) do
    Zoi.any()
  end

  defp unrecognized_keys(false) do
    :error
  end

  defp unrecognized_keys(schema) when is_map(schema) do
    {:preserve, {Zoi.string(), decode_schema(schema)}}
  end

  defp unrecognized_keys(_) do
    :preserve
  end

  defp apply_metadata(schema, json) do
    schema
    |> apply_first_class(json)
    |> apply_extra_metadata(json)
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

  defp apply_extra_metadata(schema, json) do
    pairs =
      Enum.flat_map(@metadata_keys, fn {json_key, meta_key} ->
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
