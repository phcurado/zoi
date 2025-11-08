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
    enhanced_fields =
      Enum.map(obj.fields, fn {key, type} ->
        {key, enhance_nested(type)}
      end)

    obj
    |> Map.put(:fields, enhanced_fields)
    |> apply_object_defaults()
  end

  @doc """
  Parses an object schema and returns the underlying `Zoi.Context`.

  The returned context keeps the params in `context.input`, even when validations fail,
  so it can be passed directly to `Phoenix.Component.to_form/2` or any `Phoenix.HTML`
  form helper.
  """
  @spec parse(Zoi.Types.Object.t(), Zoi.input(), Zoi.options()) :: Zoi.Context.t()
  def parse(%Zoi.Types.Object{} = obj, input, opts \\ []) do
    ctx = Zoi.Context.new(obj, input)
    opts = Keyword.put_new(opts, :ctx, ctx)

    Zoi.Context.parse(ctx, opts)
  end

  @doc """
  Appends an item to an array field in the context's input and returns a new context.

  This handles LiveView's numeric-key map format automatically.

  ## Examples

      schema = Zoi.object(%{tags: Zoi.array(Zoi.string())}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"tags" => ["a", "b"]})
      new_ctx = Zoi.Form.append(ctx, "tags", "c")
      # new_ctx.input["tags"] => ["a", "b", "c"]
  """
  @spec append(Zoi.Context.t(), binary() | atom(), any()) :: Zoi.Context.t()
  def append(%Zoi.Context{schema: schema} = ctx, field, item) do
    field_str = to_string(field)
    current_value = Map.get(ctx.input, field_str)
    current_list = to_list(current_value)
    updated_list = current_list ++ [item]
    updated_input = Map.put(ctx.input, field_str, updated_list)

    parse(schema, updated_input)
  end

  @doc """
  Removes an item at the given index from an array field and returns a new context.

  ## Examples

      schema = Zoi.object(%{tags: Zoi.array(Zoi.string())}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"tags" => ["a", "b", "c"]})
      new_ctx = Zoi.Form.delete_at(ctx, "tags", 1)
      # new_ctx.input["tags"] => ["a", "c"]
  """
  @spec delete_at(Zoi.Context.t(), binary() | atom(), non_neg_integer()) :: Zoi.Context.t()
  def delete_at(%Zoi.Context{schema: schema} = ctx, field, index) do
    field_str = to_string(field)
    current_value = Map.get(ctx.input, field_str)
    current_list = to_list(current_value)
    updated_list = List.delete_at(current_list, index)
    updated_input = Map.put(ctx.input, field_str, updated_list)

    parse(schema, updated_input)
  end

  @doc """
  Converts a value to a list, handling LiveView's numeric-key map format.

  This is useful for reading array fields from forms where LiveView can send
  arrays as maps with numeric keys like `%{"0" => %{}, "1" => %{}}`.

  ## Examples

      iex> Zoi.Form.to_list([1, 2, 3])
      [1, 2, 3]

      iex> Zoi.Form.to_list(%{"0" => "a", "1" => "b"})
      ["a", "b"]

      iex> Zoi.Form.to_list(%{})
      []

      iex> Zoi.Form.to_list(nil)
      []
  """
  @spec to_list(list() | map() | nil) :: list()
  def to_list(value) when is_list(value), do: value
  def to_list(nil), do: []

  def to_list(%{} = map) do
    cond do
      map == %{} ->
        []

      has_index_keys?(map) ->
        map
        |> Enum.filter(fn {key, _value} -> index_key?(key) end)
        |> Enum.sort_by(fn {key, _value} -> parse_index(key) end)
        |> Enum.map(fn {_key, value} -> value end)

      true ->
        [map]
    end
  end

  defp has_index_keys?(map) do
    Enum.any?(map, fn {key, _value} -> index_key?(key) end)
  end

  defp index_key?(key) when is_integer(key), do: true

  defp index_key?(key) when is_binary(key) do
    case Integer.parse(key) do
      {_int, ""} -> true
      _ -> false
    end
  end

  defp index_key?(_), do: false

  defp parse_index(key) when is_integer(key), do: key

  defp parse_index(key) when is_binary(key) do
    {int, _} = Integer.parse(key)
    int
  end

  defp enhance_nested(%Zoi.Types.Object{} = obj), do: prepare(obj)
  defp enhance_nested(%Zoi.Types.Keyword{} = keyword), do: enhance_keyword(keyword)

  defp enhance_nested(%Zoi.Types.Array{} = array) do
    array
    |> Map.put(:inner, enhance_nested(array.inner))
    |> maybe_enable_coercion()
  end

  defp enhance_nested(%Zoi.Types.Default{} = default) do
    %{default | inner: enhance_nested(default.inner)}
  end

  defp enhance_nested(%Zoi.Types.Map{} = map) do
    map =
      %{
        map
        | key_type: enhance_nested(map.key_type),
          value_type: enhance_nested(map.value_type)
      }

    maybe_enable_coercion(map)
  end

  defp enhance_nested(%Zoi.Types.Tuple{} = tuple) do
    %{tuple | fields: Enum.map(tuple.fields, &enhance_nested/1)}
  end

  defp enhance_nested(%Zoi.Types.Union{} = union) do
    %{union | schemas: Enum.map(union.schemas, &enhance_nested/1)}
  end

  defp enhance_nested(%Zoi.Types.Intersection{} = intersection) do
    %{intersection | schemas: Enum.map(intersection.schemas, &enhance_nested/1)}
  end

  defp enhance_nested(%Zoi.Types.Struct{} = struct) do
    %{struct | inner: enhance_nested(struct.inner)}
    |> maybe_enable_coercion()
  end

  defp enhance_nested(other), do: maybe_enable_coercion(other)

  defp enhance_keyword(%Zoi.Types.Keyword{fields: fields} = keyword) when is_list(fields) do
    enhanced_fields =
      Enum.map(fields, fn {key, type} ->
        {key, enhance_nested(type)}
      end)

    keyword
    |> Map.put(:fields, enhanced_fields)
    |> apply_keyword_defaults()
  end

  defp enhance_keyword(%Zoi.Types.Keyword{fields: schema} = keyword) when is_struct(schema) do
    keyword
    |> Map.put(:fields, enhance_nested(schema))
    |> apply_keyword_defaults()
  end

  defp apply_object_defaults(%Zoi.Types.Object{} = obj) do
    %{obj | coerce: true, empty_values: @form_empty_values}
  end

  defp apply_keyword_defaults(%Zoi.Types.Keyword{} = keyword) do
    %{keyword | coerce: true, empty_values: @form_empty_values}
  end

  defp maybe_enable_coercion(%{coerce: _} = type), do: %{type | coerce: true}
  defp maybe_enable_coercion(type), do: type
end
