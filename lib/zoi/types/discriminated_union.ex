defmodule Zoi.Types.DiscriminatedUnion do
  @moduledoc false

  use Zoi.Type.Def, fields: [:field, :schemas, :values, :coerce]

  def opts() do
    Zoi.Opts.meta_opts() |> Zoi.Opts.with_coerce()
  end

  def new(field, [_, _ | _] = schemas, opts) when is_atom(field) or is_binary(field) do
    {schema_map, values} = build_schema_lookup(field, schemas)
    apply_type(opts ++ [field: field, schemas: schema_map, values: values])
  end

  def new(_field, _schemas, _opts) do
    raise ArgumentError,
          "discriminated_union must receive a field (atom or string) and at least 2 schemas"
  end

  defp build_schema_lookup(field, schemas) do
    {schema_map, reversed_values} =
      Enum.reduce(schemas, {%{}, []}, fn schema, {lookup, values} ->
        value = extract_field_value(schema, field)

        if Map.has_key?(lookup, value) do
          raise ArgumentError,
                "duplicate discriminator '#{value}' found in discriminated_union schemas"
        end

        {Map.put(lookup, value, schema), [value | values]}
      end)

    {schema_map, Enum.reverse(reversed_values)}
  end

  defp extract_field_value(%Zoi.Types.Map{fields: fields} = schema, field) do
    case List.keyfind(fields, field, 0) do
      {_key, %Zoi.Types.Literal{value: value}} ->
        value

      nil ->
        raise ArgumentError,
              "all schemas must have the field '#{field}' defined, missing in: #{inspect(schema)}"

      _other ->
        raise ArgumentError, "field '#{field}' must be a literal type"
    end
  end

  defp extract_field_value(unsupported, _field) do
    raise ArgumentError,
          "all schemas in discriminated_union must be map types, got: #{inspect(unsupported)}"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.DiscriminatedUnion{} = discriminated_union, input, opts)
        when is_map(input) do
      with {:ok, value} <- get_field_value(discriminated_union, input),
           {:ok, schema} <- get_schema(discriminated_union, value) do
        Zoi.parse(schema, input, opts)
      end
    end

    def parse(schema, _input, _opts) do
      {:error, Zoi.Error.invalid_type(:map, error: schema.meta.error)}
    end

    defp get_field_value(%{field: field, coerce: coerce?} = discriminated_union, input) do
      coerced_key = if coerce?, do: to_string(field), else: field

      coerced_input =
        if coerce?, do: Map.new(input, fn {k, v} -> {to_string(k), v} end), else: input

      case Map.fetch(coerced_input, coerced_key) do
        {:ok, value} ->
          {:ok, value}

        :error ->
          if error = discriminated_union.meta.error do
            {:error, Zoi.Error.custom_error(issue: {error, [field: field]})}
          else
            {:error, Zoi.Error.required(field, path: [field])}
          end
      end
    end

    defp get_schema(%{field: field, schemas: schemas} = discriminated_union, value) do
      cond do
        schema = Map.get(schemas, value) ->
          {:ok, schema}

        error = discriminated_union.meta.error ->
          {:error, Zoi.Error.custom_error(issue: {error, [field: field, value: value]})}

        true ->
          {:error,
           Zoi.Error.custom_error(
             issue:
               {"unknown discriminator '%{value}' for field '%{field}'",
                [field: field, value: value]}
           )}
      end
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.DiscriminatedUnion{schemas: schemas, values: values}, opts) do
      values
      |> Enum.reverse()
      |> Enum.map(&Map.get(schemas, &1))
      |> Enum.map(&Zoi.TypeSpec.spec(&1, opts))
      |> Enum.reduce(&quote(do: unquote(&1) | unquote(&2)))
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      schemas = Enum.map(type.values, &Map.get(type.schemas, &1))

      schemas_doc =
        container_doc("[", schemas, "]", %Inspect.Opts{limit: 5}, fn schema, _opts ->
          Inspect.inspect(schema, opts)
        end)

      Zoi.Inspect.build(type, opts,
        field: inspect(type.field),
        schemas: schemas_doc
      )
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      one_of_schemas =
        schema.values
        |> Enum.map(&Map.get(schema.schemas, &1))
        |> Enum.map(&Zoi.JSONSchema.Encoder.encode/1)

      %{
        oneOf: one_of_schemas,
        discriminator: %{
          propertyName: to_string(schema.field)
        }
      }
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:map/0`"
  end
end
