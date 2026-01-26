defmodule Zoi.Types.KeyValue do
  @moduledoc false

  def parse(%Zoi.Types.Map{} = type, input, opts) when is_map(input) do
    input
    |> Map.to_list()
    |> do_parse_pairs(type, opts)
    |> case do
      {:ok, parsed} ->
        {:ok, Enum.into(parsed, %{})}

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

      {:error, errors, parsed} ->
        {:error, errors, Enum.into(parsed, %{})}
    end
  end

  def parse(%Zoi.Types.Keyword{} = type, input, opts) when is_list(input) do
    do_parse_pairs(input, type, opts)
    |> case do
      {:ok, parsed} ->
        {:ok, Enum.reverse(parsed)}

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
         },
         opts
       )
       when is_list(schema_fields) do
    coerce? = Keyword.get(opts, :coerce, coerce?)
    normalize_key = normalize_key_fun(coerce?)

    input_lookup = Map.new(input_pairs, fn {k, v} -> {normalize_key.(k), v} end)

    schema_keyset =
      schema_fields
      |> Enum.map(fn {k, _schema} -> normalize_key.(k) end)
      |> MapSet.new()

    unknown_pairs = reject_known_pairs(input_pairs, schema_keyset, normalize_key)

    {parsed, collected_errors} =
      Enum.reduce(schema_fields, {[], []}, fn {field_key, field_schema}, {parsed, errors} ->
        normalized = normalize_key.(field_key)

        case Map.fetch(input_lookup, normalized) do
          :error ->
            handle_missing_field(field_schema, field_key, parsed, errors)

          {:ok, raw_value} ->
            maybe_warn_deprecated(field_schema, field_key)

            if raw_value in empty_values do
              handle_missing_field(field_schema, field_key, parsed, errors)
            else
              case parse_child_value(field_schema, raw_value, opts, [field_key]) do
                {:ok, parsed_value, child_errors} ->
                  {[{field_key, parsed_value} | parsed], Zoi.Errors.merge(errors, child_errors)}

                {:error, child_errors, partial_value} ->
                  parsed =
                    if is_nil(partial_value) do
                      parsed
                    else
                      [{field_key, partial_value} | parsed]
                    end

                  {parsed, Zoi.Errors.merge(errors, child_errors)}
              end
            end
        end
      end)

    {parsed, errors} =
      case unrecognized_keys do
        :strip ->
          {parsed, collected_errors}

        :error ->
          errors =
            unknown_pairs
            |> Enum.map(fn {k, _} -> normalize_key.(k) end)
            |> Enum.uniq()
            |> Enum.map(&Zoi.Error.unrecognized_key/1)

          {parsed, Zoi.Errors.merge(collected_errors, errors)}

        :preserve ->
          {unknown_pairs ++ parsed, collected_errors}

        {:preserve, {key_schema, value_schema}} ->
          validate_preserve_schema(
            unknown_pairs,
            key_schema,
            value_schema,
            parsed,
            collected_errors,
            opts
          )
      end

    if errors == [] do
      {:ok, parsed}
    else
      {:error, errors, parsed}
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

  defp handle_missing_field(field_schema, field_key, parsed, errors) do
    cond do
      field_schema.meta.required == false ->
        {parsed, errors}

      default?(field_schema) ->
        {[{field_key, field_schema.value} | parsed], errors}

      field_schema.meta.required == nil ->
        {parsed, errors}

      true ->
        required_error = Zoi.Error.required(field_key, path: [field_key])
        {parsed, Zoi.Errors.merge(errors, [required_error])}
    end
  end

  # Helpers

  defp normalize_key_fun(true), do: &to_string/1
  defp normalize_key_fun(false), do: &Function.identity/1

  defp reject_known_pairs(input_pairs, schema_keyset, normalize_key) do
    Enum.reject(input_pairs, fn {k, _} ->
      MapSet.member?(schema_keyset, normalize_key.(k))
    end)
  end

  defp default?(%Zoi.Types.Default{}), do: true
  defp default?(_), do: false

  defp maybe_warn_deprecated(field_schema, field_key) do
    alias Zoi.Types.Meta

    case Meta.deprecated(field_schema.meta) do
      nil ->
        :ok

      message ->
        IO.warn("#{inspect(field_key)} is deprecated: #{message}", Macro.Env.stacktrace(__ENV__))
    end
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
