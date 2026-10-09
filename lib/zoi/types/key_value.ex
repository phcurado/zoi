defmodule Zoi.Types.KeyValue do
  @moduledoc false

  alias Zoi.Types.Meta

  def parse(%Zoi.Types.Map{} = type, input, opts) when is_map(input) do
    input
    |> Map.to_list()
    |> do_parse_pairs(type, opts)
    |> case do
      {:ok, parsed} ->
        {:ok, Enum.into(parsed, %{})}

      {:error, errors} ->
        {:error, errors}

      {:error, errors, parsed} ->
        {:error, errors, Enum.into(parsed, %{})}
    end
  end

  def parse(%Zoi.Types.Struct{} = type, input, opts) when is_map(input) do
    input
    |> Map.to_list()
    |> do_parse_pairs(type, opts)
    |> case do
      {:ok, parsed} ->
        {:ok, Enum.into(parsed, %{})}

      {:error, errors} ->
        {:error, errors}

      {:error, errors, parsed} ->
        {:error, errors, Enum.into(parsed, %{})}
    end
  end

  def parse(%Zoi.Types.Keyword{} = type, input, opts) when is_list(input) do
    do_parse_pairs(input, type, opts)
    |> case do
      {:ok, parsed} ->
        {:ok, Enum.reverse(parsed)}

      {:error, errors} ->
        {:error, errors}

      {:error, errors, parsed} ->
        {:error, errors, Enum.reverse(parsed)}
    end
  end

  defp do_parse_pairs(
         input_pairs,
         %_{
           fields: schema_fields,
           unrecognized_keys: unrecognized_keys,
           coerce: coerce?,
           empty_values: empty_values
         } = type,
         opts
       )
       when is_list(schema_fields) do
    coerce? = Keyword.get(opts, :coerce, coerce?)
    normalize_key = normalize_key_fun(coerce?)

    input_lookup = Map.new(input_pairs, fn {k, v} -> {normalize_key.(k), v} end)

    unknown_pairs =
      reject_known_pairs(unrecognized_keys, input_pairs, schema_fields, normalize_key)

    key_errors = type |> validate_keys(input_pairs, opts) |> Enum.reverse()

    {parsed, collected_errors} =
      Enum.reduce(schema_fields, {[], key_errors}, fn {field_key, field_schema},
                                                      {parsed, errors} ->
        normalized = normalize_key.(field_key)

        case Map.fetch(input_lookup, normalized) do
          :error ->
            handle_missing_field(field_schema, field_key, parsed, errors)

          {:ok, raw_value} ->
            if raw_value in empty_values do
              handle_missing_field(field_schema, field_key, parsed, errors)
            else
              schema = field_schema(type, normalized, field_schema)
              parse_field(field_key, raw_value, schema, opts, parsed, errors)
            end
        end
      end)

    {parsed, errors} =
      parse_unknown_pairs(
        type,
        unknown_pairs,
        normalize_key,
        opts,
        parsed,
        Enum.reverse(collected_errors)
      )

    case {errors, parsed} do
      {[], parsed} -> {:ok, parsed}
      {errors, []} -> {:error, errors}
      {errors, parsed} -> {:error, errors, parsed}
    end
  end

  defp field_schema(%Zoi.Types.Map{pattern_properties: patterns}, key, schema) do
    case Zoi.Types.Map.pattern_schemas(patterns, key) do
      [] -> schema
      matching -> Zoi.intersection([schema | matching])
    end
  end

  defp field_schema(_type, _key, schema) do
    schema
  end

  defp parse_unknown_pairs(
         %Zoi.Types.Map{pattern_properties: [_ | _]} = type,
         pairs,
         normalize_key,
         opts,
         parsed,
         errors
       ) do
    Enum.reduce(pairs, {parsed, errors}, fn {key, value} = pair, {parsed, errors} ->
      case Zoi.Types.Map.pattern_schemas(type.pattern_properties, normalize_key.(key)) do
        [] ->
          parse_unrecognized_pairs(
            [pair],
            type.unrecognized_keys,
            normalize_key,
            opts,
            parsed,
            errors
          )

        schemas ->
          {parsed, child_errors} =
            parse_field(key, value, intersect_schemas(schemas), opts, parsed, [])

          {parsed, Zoi.Errors.merge(errors, Enum.reverse(child_errors))}
      end
    end)
  end

  defp parse_unknown_pairs(type, pairs, normalize_key, opts, parsed, errors) do
    parse_unrecognized_pairs(pairs, type.unrecognized_keys, normalize_key, opts, parsed, errors)
  end

  defp parse_unrecognized_pairs(pairs, mode, normalize_key, opts, parsed, errors) do
    case mode do
      :strip ->
        {parsed, errors}

      :error ->
        key_errors =
          pairs
          |> Enum.map(fn {key, _value} -> normalize_key.(key) end)
          |> Enum.uniq()
          |> Enum.map(&Zoi.Error.unrecognized_key/1)

        {parsed, Zoi.Errors.merge(errors, key_errors)}

      :preserve ->
        {pairs ++ parsed, errors}

      {:preserve, {key_schema, value_schema}} ->
        validate_preserve_schema(pairs, key_schema, value_schema, parsed, errors, opts)
    end
  end

  defp intersect_schemas([schema]) do
    schema
  end

  defp intersect_schemas(schemas) do
    Zoi.intersection(schemas)
  end

  defp parse_field(key, value, schema, opts, parsed, errors) do
    case parse_child_value(schema, value, opts, [key]) do
      {:ok, parsed_value, child_errors} ->
        {[{key, parsed_value} | parsed], Enum.reverse(child_errors, errors)}

      {:error, child_errors, partial_value} ->
        parsed =
          if is_nil(partial_value) do
            parsed
          else
            [{key, partial_value} | parsed]
          end

        {parsed, Enum.reverse(child_errors, errors)}
    end
  end

  # Turn a field value into {:ok, value, errs} or {:error, errs, partial}
  # Ensures errs is flat and has the path prepended.
  defp parse_child_value(field_schema, raw_value, opts, path) do
    ctx =
      Zoi.Context.new(field_schema, raw_value)
      |> Zoi.Context.add_path(path)

    ctx = Zoi.Context.parse(ctx, opts)

    if ctx.valid? do
      {:ok, ctx.parsed, []}
    else
      errors = Enum.map(ctx.errors, &Zoi.Error.prepend_path(&1, path))
      {:error, errors, ctx.parsed}
    end
  end

  defp validate_keys(%Zoi.Types.Map{key_type: key_type}, input_pairs, opts)
       when not is_nil(key_type) do
    Enum.flat_map(input_pairs, fn {key, _value} ->
      case parse_child_value(key_type, key, opts, [key]) do
        {:ok, _, errors} -> errors
        {:error, errors, _} -> errors
      end
    end)
  end

  defp validate_keys(_type, _input_pairs, _opts) do
    []
  end

  defp handle_missing_field(field_schema, field_key, parsed, errors) do
    cond do
      field_schema.meta.required == false ->
        {parsed, errors}

      Meta.default?(field_schema.meta) ->
        {[{field_key, Meta.default(field_schema.meta)} | parsed], errors}

      field_schema.meta.required == nil ->
        {parsed, errors}

      true ->
        required_error = Zoi.Error.required(field_key, path: [field_key])
        {parsed, [required_error | errors]}
    end
  end

  # Helpers

  defp normalize_key_fun(true), do: &to_string/1
  defp normalize_key_fun(false), do: &Function.identity/1

  defp reject_known_pairs(:strip, _input_pairs, _schema_fields, _normalize_key), do: []

  defp reject_known_pairs(_mode, input_pairs, schema_fields, normalize_key) do
    schema_keyset =
      schema_fields
      |> Enum.map(fn {k, _schema} -> normalize_key.(k) end)
      |> MapSet.new()

    Enum.reject(input_pairs, fn {k, _} ->
      MapSet.member?(schema_keyset, normalize_key.(k))
    end)
  end

  defp validate_preserve_schema(unknown_pairs, key_schema, value_schema, parsed, errors, opts) do
    unknown_map = Map.new(unknown_pairs)
    temp_schema = Zoi.map(key_schema, value_schema)

    case Zoi.Type.parse(temp_schema, unknown_map, opts) do
      {:ok, validated_map} ->
        {Map.to_list(validated_map) ++ parsed, errors}

      {:error, new_errors, _partial} ->
        {parsed, Zoi.Errors.merge(errors, new_errors)}
    end
  end
end
