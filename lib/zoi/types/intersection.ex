defmodule Zoi.Types.Intersection do
  @moduledoc false

  use Zoi.Type.Def, fields: [:schemas]

  def new([], _opts) do
    raise ArgumentError, "Intersection type must be receive a list of minimum 2 schemas"
  end

  def new([_one_element], _opts) do
    raise ArgumentError, "Intersection type must be receive a list of minimum 2 schemas"
  end

  def new(schemas, opts) when is_list(schemas) do
    apply_type(opts ++ [schemas: schemas])
  end

  def new(_schemas, _opts) do
    raise ArgumentError, "Intersection type must be receive a list of minimum 2 schemas"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Intersection{schemas: schemas} = intersection, value, opts) do
      Enum.reduce_while(schemas, nil, fn schema, acc ->
        ctx = Zoi.Context.new(schema, value)
        opts = Keyword.put(opts, :ctx, ctx)

        case Zoi.parse(schema, value, opts) do
          {:ok, result} ->
            case combine_results(acc, result) do
              {:ok, combined} -> {:cont, {:ok, combined}}
              {:error, reason} -> {:halt, error(intersection, reason)}
            end

          {:error, reason} ->
            {:halt, error(intersection, reason)}
        end
      end)
    end

    defp combine_results({:ok, left}, right)
         when is_map(left) and not is_struct(left) and is_map(right) and not is_struct(right),
         do: merge_objects(left, right, [])

    # Preserve the existing last-result contract for scalar coercion and other types.
    defp combine_results(_acc, result), do: {:ok, result}

    defp merge_objects(left, right, path) do
      Enum.reduce_while(right, {:ok, left}, fn {key, value}, {:ok, combined} ->
        case Map.fetch(combined, key) do
          :error ->
            {:cont, {:ok, Map.put(combined, key, value)}}

          {:ok, previous} ->
            case merge_field(previous, value, path ++ [key]) do
              {:ok, merged} -> {:cont, {:ok, Map.put(combined, key, merged)}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
        end
      end)
    end

    defp merge_field(left, right, _path) when left === right, do: {:ok, left}

    defp merge_field(left, right, path)
         when is_map(left) and not is_struct(left) and is_map(right) and not is_struct(right),
         do: merge_objects(left, right, path)

    defp merge_field(_left, _right, path) do
      {:error,
       Zoi.Error.custom_error(
         issue: {"intersection branches produced conflicting field values", []},
         path: path
       )}
    end

    defp error(schema, type_error) do
      if error = schema.meta.error do
        {:error, Zoi.Error.custom_error(issue: {error, []})}
      else
        {:error, type_error}
      end
    end
  end

  # There is no direct representation of a intersection in Elixir types, so we use union `|`
  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Intersection{schemas: schemas}, opts) do
      Enum.map(schemas, &Zoi.type_spec(&1, opts))
      |> Enum.reverse()
      |> Enum.reduce(&quote(do: unquote(&1) | unquote(&2)))
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      schemas_doc =
        container_doc("[", type.schemas, "]", %Inspect.Opts{limit: 5}, fn
          schema, _opts -> Inspect.inspect(schema, opts)
        end)

      Zoi.Inspect.build(type, opts, schemas: schemas_doc)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{allOf: Enum.map(schema.schemas, &Zoi.JSONSchema.encode_schema/1)}
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(%{schemas: schemas}) do
      Enum.map_join(schemas, " and ", &Zoi.Describe.Encoder.encode/1)
    end
  end
end
