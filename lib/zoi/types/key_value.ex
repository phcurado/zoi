defmodule Zoi.Types.KeyValue do
  @moduledoc false
  # Shared parsing logic for Zoi.Types.Object and Zoi.Types.Keyword

  alias Zoi.Types.Meta

  def parse(%Zoi.Types.Object{} = type, input, opts) when is_map(input) do
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

  # One straight-line function:
  # 1) choose a key normalizer (identity/to_string)
  # 2) build a lookup map of input
  # 3) compute unknown-key errors (if strict)
  # 4) walk declared schema fields in order
  # 5) finalize container + merge errors
  defp do_parse_pairs(
         input_pairs,
         %_{fields: schema_fields, strict: strict?, coerce: coerce?, empty_values: empty_values},
         opts
       )
       when is_list(schema_fields) do
    normalize_key = normalize_key_fun(coerce?)

    input_lookup =
      input_pairs
      |> Map.new(fn {k, v} -> {normalize_key.(k), v} end)

    schema_keyset =
      schema_fields
      |> Enum.map(fn {k, _schema} -> normalize_key.(k) end)
      |> MapSet.new()

    unknown_key_errors =
      if strict? do
        input_pairs
        |> Stream.map(fn {k, _} -> normalize_key.(k) end)
        |> Stream.reject(&MapSet.member?(schema_keyset, &1))
        |> Enum.uniq()
        |> Enum.map(&Zoi.Error.unrecognized_key/1)
      else
        []
      end

    {parsed, collected_errors} =
      Enum.reduce(schema_fields, {[], []}, fn {field_key, field_schema}, {parsed, errors} ->
        normalized = normalize_key.(field_key)

        case Map.fetch(input_lookup, normalized) do
          :error ->
            handle_missing_field(field_schema, field_key, parsed, errors)

          {:ok, raw_value} ->
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

    errors = Zoi.Errors.merge(collected_errors, unknown_key_errors)

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
      Meta.optional?(field_schema.meta) ->
        {parsed, errors}

      default?(field_schema) ->
        {[{field_key, field_schema.value} | parsed], errors}

      true ->
        required_error = Zoi.Error.required(field_key, path: [field_key])
        {parsed, Zoi.Errors.merge(errors, [required_error])}
    end
  end

  # Helpers

  defp normalize_key_fun(true), do: &to_string/1
  defp normalize_key_fun(false), do: &Function.identity/1

  defp default?(%Zoi.Types.Default{}), do: true
  defp default?(_), do: false
end
