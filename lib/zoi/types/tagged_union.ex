defmodule Zoi.Types.TaggedUnion do
  @moduledoc false

  use Zoi.Type.Def, fields: [:tag, :schemas, :tag_values, :coerce]

  def opts() do
    Zoi.Opts.meta_opts() |> Zoi.Opts.with_coerce()
  end

  def new(tag, [_, _ | _] = schemas, opts) when is_atom(tag) or is_binary(tag) do
    {schema_map, tag_values} = build_schema_lookup(tag, schemas)
    apply_type(opts ++ [tag: tag, schemas: schema_map, tag_values: tag_values])
  end

  def new(_tag, _schemas, _opts) do
    raise ArgumentError, "tagged_union must receive a tag (atom or string) and at least 2 schemas"
  end

  defp build_schema_lookup(tag, schemas) do
    {schema_map, reversed_tag_values} =
      Enum.reduce(schemas, {%{}, []}, fn schema, {lookup, tag_values} ->
        tag_value = extract_tag_value(schema, tag)

        if Map.has_key?(lookup, tag_value) do
          raise ArgumentError, "duplicate tag value '#{tag_value}' found in tagged_union schemas"
        end

        {Map.put(lookup, tag_value, schema), [tag_value | tag_values]}
      end)

    {schema_map, Enum.reverse(reversed_tag_values)}
  end

  defp extract_tag_value(%Zoi.Types.Map{fields: fields} = schema, tag) do
    case List.keyfind(fields, tag, 0) do
      {_key, %Zoi.Types.Literal{value: value}} ->
        value

      nil ->
        raise ArgumentError,
              "all schemas must have the tag field '#{tag}' defined, missing in: #{inspect(schema)}"

      _other ->
        raise ArgumentError, "tag field '#{tag}' must be a literal type"
    end
  end

  defp extract_tag_value(unsupported, _tag) do
    raise ArgumentError,
          "all schemas in tagged_union must be map types, got: #{inspect(unsupported)}"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.TaggedUnion{} = tagged_union, input, opts) when is_map(input) do
      with {:ok, tag_value} <- get_tag_value(tagged_union, input),
           {:ok, schema} <- get_schema(tagged_union, tag_value) do
        Zoi.parse(schema, input, opts)
      end
    end

    def parse(schema, _input, _opts) do
      {:error, Zoi.Error.invalid_type(:map, error: schema.meta.error)}
    end

    defp get_tag_value(%{tag: tag, coerce: coerce?} = tagged_union, input) do
      coerced_key = if coerce?, do: to_string(tag), else: tag

      coerced_input =
        if coerce?, do: Map.new(input, fn {k, v} -> {to_string(k), v} end), else: input

      case Map.fetch(coerced_input, coerced_key) do
        {:ok, value} ->
          {:ok, value}

        :error ->
          if error = tagged_union.meta.error do
            {:error, Zoi.Error.custom_error(issue: {error, [tag: tag]})}
          else
            {:error, Zoi.Error.required(tag, path: [tag])}
          end
      end
    end

    defp get_schema(%{tag: tag, schemas: schemas} = tagged_union, tag_value) do
      cond do
        schema = Map.get(schemas, tag_value) ->
          {:ok, schema}

        error = tagged_union.meta.error ->
          {:error, Zoi.Error.custom_error(issue: {error, [tag: tag, value: tag_value]})}

        true ->
          {:error,
           Zoi.Error.custom_error(
             issue:
               {"unknown tag value '%{value}' for discriminator '%{tag}'",
                [tag: tag, value: tag_value]}
           )}
      end
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.TaggedUnion{schemas: schemas, tag_values: tag_values}, opts) do
      tag_values
      |> Enum.reverse()
      |> Enum.map(&Map.get(schemas, &1))
      |> Enum.map(&Zoi.TypeSpec.spec(&1, opts))
      |> Enum.reduce(&quote(do: unquote(&1) | unquote(&2)))
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      schemas = Enum.map(type.tag_values, &Map.get(type.schemas, &1))

      schemas_doc =
        container_doc("[", schemas, "]", %Inspect.Opts{limit: 5}, fn schema, _opts ->
          Inspect.inspect(schema, opts)
        end)

      Zoi.Inspect.build(type, opts, tag: inspect(type.tag), schemas: schemas_doc)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      one_of_schemas =
        schema.tag_values
        |> Enum.map(&Map.get(schema.schemas, &1))
        |> Enum.map(&Zoi.JSONSchema.Encoder.encode/1)

      %{
        oneOf: one_of_schemas,
        discriminator: %{
          propertyName: to_string(schema.tag)
        }
      }
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:map/0`"
  end
end
