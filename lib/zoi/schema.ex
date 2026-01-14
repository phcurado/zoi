defmodule Zoi.Schema do
  @moduledoc """
  Utilities for traversing and transforming Zoi schemas.

  This module provides functions to recursively walk through schema structures
  and apply transformations. This is useful for applying defaults, enabling
  features like coercion, or wrapping types across an entire schema tree.

  The traversal is post-order, meaning child nodes are transformed before their
  parents, allowing transformations to work with already-processed nested schemas.

  ## Examples

      # Enable coercion on all types
      schema = Zoi.map(%{
        name: Zoi.string(),
        age: Zoi.integer()
      })
      |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Apply nullish to all fields
      schema
      |> Zoi.Schema.traverse(&Zoi.nullish/1)

      # Conditional transformation based on field path
      schema = Zoi.map(%{
        password: Zoi.string(),
        email: Zoi.string()
      })
      |> Zoi.Schema.traverse(fn node, path ->
        if :password in path do
          node
        else
          Zoi.coerce(node)
        end
      end)

      # Chain multiple transformations
      schema
      |> Zoi.Schema.traverse(&Zoi.nullish/1)
      |> Zoi.Schema.traverse(&Zoi.coerce/1)
  """

  @doc """
  Traverses a schema tree and applies a transformation function to each node.

  The traversal walks through nested schemas (objects, arrays, unions, maps, tuples, etc.)
  and applies the transformation function to each child node. The root node is not transformed.

  The transformation function receives the current node and optionally the path (list of field
  keys showing the location in the schema tree, e.g., `[:user, :address, :street]`).

  ## Examples

      # Enable coercion on all nested fields
      schema
      |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Apply transformation conditionally using path
      schema
      |> Zoi.Schema.traverse(fn node, path ->
        if :password in path do
          node
        else
          Zoi.coerce(node)
        end
      end)
  """
  @spec traverse(Zoi.schema(), function()) :: Zoi.schema()
  def traverse(schema, fun) when is_function(fun, 1) or is_function(fun, 2) do
    do_traverse_root(schema, fun)
  end

  defp do_traverse_root(%Zoi.Types.Map{fields: fields} = obj, fun) when is_list(fields) do
    transformed_fields =
      Enum.map(fields, fn {key, type} ->
        {key, do_traverse(type, [key], fun)}
      end)

    Map.put(obj, :fields, transformed_fields)
  end

  defp do_traverse_root(%Zoi.Types.Struct{fields: fields} = struct, fun) do
    transformed_fields =
      Enum.map(fields, fn {key, type} ->
        {key, do_traverse(type, [key], fun)}
      end)

    Map.put(struct, :fields, transformed_fields)
  end

  defp do_traverse_root(%Zoi.Types.Keyword{fields: fields} = keyword, fun) when is_list(fields) do
    transformed_fields =
      Enum.map(fields, fn {key, type} ->
        {key, do_traverse(type, [key], fun)}
      end)

    Map.put(keyword, :fields, transformed_fields)
  end

  defp do_traverse_root(%Zoi.Types.Keyword{fields: schema} = keyword, fun)
       when is_struct(schema) do
    Map.put(keyword, :fields, do_traverse(schema, [], fun))
  end

  defp do_traverse_root(
         %Zoi.Types.DiscriminatedUnion{schemas: schemas} = discriminated_union,
         fun
       ) do
    transformed_schemas =
      Map.new(schemas, fn {key, schema} ->
        {key, do_traverse(schema, [], fun)}
      end)

    Map.put(discriminated_union, :schemas, transformed_schemas)
  end

  defp do_traverse_root(schema, _fun), do: schema

  defp do_traverse(%Zoi.Types.Map{fields: fields} = obj, path, fun) when is_list(fields) do
    transformed_fields =
      Enum.map(fields, fn {key, type} ->
        {key, do_traverse(type, path ++ [key], fun)}
      end)

    obj
    |> Map.put(:fields, transformed_fields)
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Struct{fields: fields} = struct, path, fun) do
    transformed_fields =
      Enum.map(fields, fn {key, type} ->
        {key, do_traverse(type, path ++ [key], fun)}
      end)

    struct
    |> Map.put(:fields, transformed_fields)
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Keyword{fields: fields} = keyword, path, fun)
       when is_list(fields) do
    transformed_fields =
      Enum.map(fields, fn {key, type} ->
        {key, do_traverse(type, path ++ [key], fun)}
      end)

    keyword
    |> Map.put(:fields, transformed_fields)
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Keyword{fields: schema} = keyword, path, fun)
       when is_struct(schema) do
    keyword
    |> Map.put(:fields, do_traverse(schema, path, fun))
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Array{inner: inner} = array, path, fun) do
    array
    |> Map.put(:inner, do_traverse(inner, path, fun))
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Default{inner: inner} = default, path, fun) do
    default
    |> Map.put(:inner, do_traverse(inner, path, fun))
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Map{key_type: key_type, value_type: value_type} = map, path, fun) do
    map
    |> Map.put(:key_type, do_traverse(key_type, path, fun))
    |> Map.put(:value_type, do_traverse(value_type, path, fun))
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Tuple{fields: fields} = tuple, path, fun) do
    transformed_fields = Enum.map(fields, &do_traverse(&1, path, fun))

    tuple
    |> Map.put(:fields, transformed_fields)
    |> apply_fun(path, fun)
  end

  defp do_traverse(
         %Zoi.Types.DiscriminatedUnion{schemas: schemas} = discriminated_union,
         path,
         fun
       ) do
    transformed_schemas =
      Map.new(schemas, fn {key, schema} ->
        {key, do_traverse(schema, path, fun)}
      end)

    discriminated_union
    |> Map.put(:schemas, transformed_schemas)
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Union{schemas: schemas} = union, path, fun) do
    transformed_schemas = Enum.map(schemas, &do_traverse(&1, path, fun))

    union
    |> Map.put(:schemas, transformed_schemas)
    |> apply_fun(path, fun)
  end

  defp do_traverse(%Zoi.Types.Intersection{schemas: schemas} = intersection, path, fun) do
    transformed_schemas = Enum.map(schemas, &do_traverse(&1, path, fun))

    intersection
    |> Map.put(:schemas, transformed_schemas)
    |> apply_fun(path, fun)
  end

  # Lazy types are treated as leaf nodes, we don't traverse into them
  # because they may contain recursive references that would cause infinite loops.
  # The transformation is applied to the Lazy wrapper only.
  defp do_traverse(%Zoi.Types.Lazy{} = lazy, path, fun) do
    apply_fun(lazy, path, fun)
  end

  defp do_traverse(schema, path, fun) do
    apply_fun(schema, path, fun)
  end

  # Apply function based on arity
  defp apply_fun(schema, _path, fun) when is_function(fun, 1), do: fun.(schema)
  defp apply_fun(schema, path, fun) when is_function(fun, 2), do: fun.(schema, path)
end
