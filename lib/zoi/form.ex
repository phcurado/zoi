defmodule Zoi.Form do
  @moduledoc """
  Helpers for integrating `Zoi` objects with Phoenix (or any `Phoenix.HTML.FormData`)
  forms.

  This module focuses on turning your object schemas into form-friendly schemas and
  returning a `%Zoi.Context{}` that implements the `Phoenix.HTML.FormData`
  protocol.
  """

  @form_empty_values [nil, ""]

  @doc """
  Tweaks an object schema to work nicely with HTML forms.

  This function enables coercion on all nested fields so string params are coerced
  into their target type and sets the empty values to `nil` and `""`, matching how
  Phoenix sends form inputs.
  """
  @spec prepare(Zoi.Type.t()) :: Zoi.Type.t()
  def prepare(%Zoi.Types.Object{} = obj) do
    obj
    |> Zoi.Schema.traverse(fn
      %Zoi.Types.Object{} = inner_obj ->
        apply_object_defaults(inner_obj)

      %Zoi.Types.Struct{} = struct ->
        apply_struct_defaults(struct)

      %Zoi.Types.Keyword{fields: fields} = keyword when is_list(fields) ->
        apply_keyword_defaults(keyword)

      %Zoi.Types.Keyword{fields: schema} = keyword when is_struct(schema) ->
        apply_keyword_defaults(keyword)

      node ->
        Zoi.coerce(node)
    end)
    |> apply_object_defaults()
  end

  def prepare(%Zoi.Types.Struct{} = struct) do
    struct
    |> Zoi.Schema.traverse(fn
      %Zoi.Types.Object{} = obj ->
        apply_object_defaults(obj)

      %Zoi.Types.Struct{} = inner_struct ->
        apply_struct_defaults(inner_struct)

      %Zoi.Types.Keyword{fields: fields} = keyword when is_list(fields) ->
        apply_keyword_defaults(keyword)

      %Zoi.Types.Keyword{fields: schema} = keyword when is_struct(schema) ->
        apply_keyword_defaults(keyword)

      node ->
        Zoi.coerce(node)
    end)
    |> apply_struct_defaults()
  end

  @doc """
  Parses an object schema and returns the underlying `Zoi.Context`.

  The returned context keeps the params in `context.input`, even when validations fail,
  so it can be passed directly to `Phoenix.Component.to_form/2` or any `Phoenix.HTML`
  form helper.

  This function automatically normalizes LiveView's map-based array format (with numeric
  string keys) into regular lists, so `context.input` always contains clean, manipulable
  data structures.
  """
  @spec parse(schema :: Zoi.Type.t(), input :: Zoi.input(), opts :: Zoi.options()) ::
          Zoi.Context.t()
  def parse(%Zoi.Types.Object{} = obj, input, opts \\ []) do
    # Normalize input to convert LiveView map arrays to lists
    normalized_input = normalize_input(obj, input)

    ctx = Zoi.Context.new(obj, normalized_input)
    opts = Keyword.put_new(opts, :ctx, ctx)

    Zoi.Context.parse(ctx, opts)
  end

  # Recursively normalize input based on schema structure
  defp normalize_input(%Zoi.Types.Object{fields: fields}, input) when is_map(input) do
    Enum.reduce(fields, input, fn {key, type}, acc ->
      key_str = to_string(key)

      case Map.get(acc, key_str) do
        nil -> acc
        value -> Map.put(acc, key_str, normalize_value(type, value))
      end
    end)
  end

  defp normalize_input(_schema, input), do: input

  defp normalize_value(%Zoi.Types.Array{inner: inner}, value)
       when is_list(value) or is_map(value) do
    list = map_to_list(value)
    Enum.map(list, &normalize_value(inner, &1))
  end

  defp normalize_value(%Zoi.Types.Object{} = obj, value) when is_map(value) do
    normalize_input(obj, value)
  end

  defp normalize_value(%Zoi.Types.Default{inner: inner}, value) do
    normalize_value(inner, value)
  end

  defp normalize_value(_type, value), do: value

  # Convert LiveView's numeric-key map format to a list
  defp map_to_list(value) when is_list(value), do: value
  defp map_to_list(%{} = map) when map_size(map) == 0, do: []

  defp map_to_list(map) when is_map(map) do
    if has_numeric_keys?(map) do
      map
      |> Enum.filter(fn {key, _value} -> numeric_key?(key) end)
      |> Enum.sort_by(fn {key, _value} -> parse_key_index(key) end)
      |> Enum.map(fn {_key, value} -> value end)
    else
      [map]
    end
  end

  defp has_numeric_keys?(map) do
    Enum.any?(map, fn {key, _value} -> numeric_key?(key) end)
  end

  defp numeric_key?(key) when is_integer(key), do: true

  defp numeric_key?(key) when is_binary(key) do
    case Integer.parse(key) do
      {_int, ""} -> true
      _ -> false
    end
  end

  defp parse_key_index(key) when is_integer(key), do: key

  defp parse_key_index(key) when is_binary(key) do
    {int, _} = Integer.parse(key)
    int
  end

  defp apply_object_defaults(%Zoi.Types.Object{} = obj) do
    %{obj | coerce: true, empty_values: @form_empty_values}
  end

  defp apply_struct_defaults(%Zoi.Types.Struct{} = obj) do
    %{obj | coerce: true, empty_values: @form_empty_values}
  end

  defp apply_keyword_defaults(%Zoi.Types.Keyword{} = keyword) do
    %{keyword | coerce: true, empty_values: @form_empty_values}
  end
end
