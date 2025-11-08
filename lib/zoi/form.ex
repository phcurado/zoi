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

  The returned context keeps the raw params in `context.input`, even when
  validations fail, so it can be passed directly to `Phoenix.Component.to_form/2`
  or any `Phoenix.HTML` form helper.
  """
  @spec parse(Zoi.Types.Object.t(), Zoi.input(), Zoi.options()) :: Zoi.Context.t()
  def parse(%Zoi.Types.Object{} = obj, input, opts \\ []) do
    ctx = Zoi.Context.new(obj, input)
    opts = Keyword.put_new(opts, :ctx, ctx)

    Zoi.Context.parse(ctx, opts)
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
