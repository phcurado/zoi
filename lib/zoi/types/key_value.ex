defmodule Zoi.Types.KeyValue do
  @moduledoc false

  alias Zoi.Types.Meta

  def parse(%Zoi.Types.Map{} = type, input, opts) when is_map(input) do
    input
    |> do_parse(type, opts)
    |> to_map_result()
  end

  def parse(%Zoi.Types.Struct{} = type, input, opts) when is_map(input) do
    input
    |> do_parse(type, opts)
    |> to_map_result()
  end

  def parse(%Zoi.Types.Keyword{} = type, input, opts) when is_list(input) do
    input
    |> do_parse(type, opts)
    |> to_keyword_result()
  end

  defp do_parse(
         input,
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
    lookup = build_lookup(input, coerce?)
    patterns = Map.get(type, :pattern_properties, [])
    unknown_pairs = reject_known_pairs(unrecognized_keys, input, schema_fields, coerce?)
    key_errors = type |> validate_keys(input, opts) |> Enum.reverse()

    {parsed, collected_errors} =
      Enum.reduce(schema_fields, {[], key_errors}, fn {field_key, field_schema},
                                                      {parsed, errors} ->
        case fetch_field(lookup, field_key, coerce?) do
          :error ->
            handle_missing_field(field_schema, field_key, parsed, errors)

          :collision ->
            {parsed, [Zoi.Error.key_collision(field_key) | errors]}

          {:ok, raw_value} ->
            if empty_values != [] and raw_value in empty_values do
              handle_missing_field(field_schema, field_key, parsed, errors)
            else
              path = [field_key]

              result =
                field_schema
                |> parse_child_value(raw_value, opts, path)
                |> maybe_validate_patterns(patterns, field_key, coerce?, raw_value, opts, path)

              collect_field(result, field_key, parsed, errors)
            end
        end
      end)

    {unknown_pairs, {parsed, collected_errors}} =
      parse_pattern_pairs(unknown_pairs, patterns, coerce?, opts, {parsed, collected_errors})

    collected_errors = Enum.reverse(collected_errors)

    {parsed, errors} =
      handle_unrecognized_keys(
        unrecognized_keys,
        unknown_pairs,
        coerce?,
        parsed,
        collected_errors,
        opts
      )

    case {errors, parsed} do
      {[], parsed} -> {:ok, parsed}
      {errors, []} -> {:error, errors}
      {errors, parsed} -> {:error, errors, parsed}
    end
  end

  defp build_lookup(input, false) when is_map(input), do: input
  defp build_lookup(input, false) when is_list(input), do: Map.new(input)
  defp build_lookup(input, true) when is_map(input), do: build_coerced_lookup(input)

  defp build_lookup(input, true) when is_list(input),
    do: input |> Map.new() |> build_coerced_lookup()

  defp build_coerced_lookup(input) do
    :maps.fold(
      fn key, value, acc ->
        normalized = to_string(key)

        case acc do
          %{^normalized => _} -> Map.put(acc, normalized, :collision)
          _ -> Map.put(acc, normalized, {:ok, value})
        end
      end,
      %{},
      input
    )
  end

  defp fetch_field(lookup, field_key, false), do: Map.fetch(lookup, field_key)
  defp fetch_field(lookup, field_key, true), do: Map.get(lookup, to_string(field_key), :error)

  defp to_map_result({:ok, parsed}), do: {:ok, :maps.from_list(parsed)}
  defp to_map_result({:error, errors}), do: {:error, errors}
  defp to_map_result({:error, errors, parsed}), do: {:error, errors, :maps.from_list(parsed)}

  defp to_keyword_result({:ok, parsed}), do: {:ok, Enum.reverse(parsed)}
  defp to_keyword_result({:error, errors}), do: {:error, errors}
  defp to_keyword_result({:error, errors, parsed}), do: {:error, errors, Enum.reverse(parsed)}

  defp handle_unrecognized_keys(:strip, _unknown_pairs, _coerce?, parsed, errors, _opts) do
    {parsed, errors}
  end

  defp handle_unrecognized_keys(_mode, [], _coerce?, parsed, errors, _opts) do
    {parsed, errors}
  end

  defp handle_unrecognized_keys(:error, unknown_pairs, coerce?, parsed, errors, _opts) do
    unrecognized_errors =
      unknown_pairs
      |> Enum.map(fn {key, _value} -> normalize_key(key, coerce?) end)
      |> Enum.uniq()
      |> Enum.map(&Zoi.Error.unrecognized_key/1)

    {parsed, Zoi.Errors.merge(errors, unrecognized_errors)}
  end

  defp handle_unrecognized_keys(:preserve, unknown_pairs, _coerce?, parsed, errors, _opts) do
    {unknown_pairs ++ parsed, errors}
  end

  defp handle_unrecognized_keys(
         {:preserve, {key_schema, value_schema}},
         unknown_pairs,
         _coerce?,
         parsed,
         errors,
         opts
       ) do
    validate_preserve_schema(unknown_pairs, key_schema, value_schema, parsed, errors, opts)
  end

  defp maybe_validate_patterns(result, [], _field_key, _coerce?, _value, _opts, _path) do
    result
  end

  defp maybe_validate_patterns(result, patterns, field_key, coerce?, value, opts, path) do
    case Zoi.Types.Map.pattern_schemas(patterns, normalize_key(field_key, coerce?)) do
      [] -> result
      schemas -> validate_patterns(result, schemas, value, opts, path)
    end
  end

  defp parse_pattern_pairs(pairs, [], _coerce?, _opts, acc), do: {pairs, acc}

  defp parse_pattern_pairs(pairs, patterns, coerce?, opts, acc) do
    Enum.flat_map_reduce(pairs, acc, fn {key, value} = pair, {parsed, errors} ->
      case Zoi.Types.Map.pattern_schemas(patterns, normalize_key(key, coerce?)) do
        [] ->
          {[pair], {parsed, errors}}

        schemas ->
          result = validate_patterns({:ok, value}, schemas, value, opts, [key])
          {[], collect_field(result, key, parsed, errors)}
      end
    end)
  end

  defp validate_patterns({:ok, _value} = result, schemas, value, opts, path) do
    Enum.find_value(schemas, result, fn schema ->
      case parse_child_value(schema, value, opts, path) do
        {:ok, _parsed} -> nil
        error -> error
      end
    end)
  end

  defp validate_patterns(error, _schemas, _value, _opts, _path), do: error

  defp collect_field({:ok, parsed_value}, key, parsed, errors) do
    {[{key, parsed_value} | parsed], errors}
  end

  defp collect_field({:error, child_errors, nil}, _key, parsed, errors) do
    {parsed, Enum.reverse(child_errors, errors)}
  end

  defp collect_field({:error, child_errors, partial_value}, key, parsed, errors) do
    {[{key, partial_value} | parsed], Enum.reverse(child_errors, errors)}
  end

  # Turn a field value into {:ok, value} or {:error, errs, partial}
  # Ensures errs is flat and has the path prepended.
  defp parse_child_value(field_schema, raw_value, opts, path) do
    case Zoi.Context.parse_value(field_schema, raw_value, opts, path) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, errors, partial} ->
        {:error, Enum.map(errors, &Zoi.Error.prepend_path(&1, path)), partial}
    end
  end

  defp validate_keys(%Zoi.Types.Map{key_type: key_type}, input, opts)
       when not is_nil(key_type) do
    Enum.flat_map(input, fn {key, _value} ->
      case parse_child_value(key_type, key, opts, [key]) do
        {:ok, _} -> []
        {:error, errors, _} -> errors
      end
    end)
  end

  defp validate_keys(_type, _input, _opts) do
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

  defp normalize_key(key, true), do: to_string(key)
  defp normalize_key(key, false), do: key

  defp reject_known_pairs(:strip, _input, _schema_fields, _coerce?), do: []

  defp reject_known_pairs(_mode, input, schema_fields, coerce?) do
    schema_keyset =
      MapSet.new(schema_fields, fn {key, _schema} -> normalize_key(key, coerce?) end)

    Enum.reject(input, fn {key, _value} ->
      MapSet.member?(schema_keyset, normalize_key(key, coerce?))
    end)
  end

  defp validate_preserve_schema(unknown_pairs, key_schema, value_schema, parsed, errors, opts) do
    unknown_map = Map.new(unknown_pairs)
    schema = Zoi.Types.Map.new(key_schema, value_schema, [])

    case Zoi.Type.parse(schema, unknown_map, opts) do
      {:ok, validated_map} ->
        {Map.to_list(validated_map) ++ parsed, errors}

      {:error, new_errors, partial} ->
        {Map.to_list(partial) ++ parsed, Zoi.Errors.merge(errors, new_errors)}
    end
  end
end
