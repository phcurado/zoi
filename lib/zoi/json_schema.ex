defmodule Zoi.JSONSchema do
  @moduledoc """
  [JSON Schema](https://json-schema.org/) is a declarative language for annotating and validating JSON document's structure, constraints, and data types. It helps you standardize and define expectations for JSON data.

  `Zoi` provides functionality to convert its type definitions into JSON Schema format, enabling seamless integration with systems that utilize JSON Schema for data validation and documentation.

  ## Example

      iex> schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})
      iex> Zoi.to_json_schema(schema)
      %{
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: :object,
        properties: %{
          name: %{type: :string},
          age: %{type: :integer}
        },
        required: [:name, :age],
        additionalProperties: false
      }

  ## Supported Types

  The following `Zoi` types are supported for conversion to JSON Schema:

    - `Zoi.string/0`
    - `Zoi.integer/0`
    - `Zoi.float/0`
    - `Zoi.number/0`
    - `Zoi.boolean/0`
    - `Zoi.literal/1`
    - `Zoi.null/0`
    - `Zoi.array/1`
    - `Zoi.tuple/1`
    - `Zoi.enum/1`
    - `Zoi.map/0`
    - `Zoi.object/1`
    - `Zoi.intersection/1`
    - `Zoi.union/1`
    - `Zoi.nullable/1`

  ## Limitations

  - Complex types or custom types not listed above will raise an error during conversion.
  - Some advanced `Zoi` features may not have direct equivalents in JSON Schema.
  - Refinements are partially supported, primarily for string patterns and length constraints.
  - Additional properties in objects are disallowed by default (`additionalProperties: false`).

  ## References

  - [JSON Schema Official Website](https://json-schema.org/)
  """

  alias Zoi.Types.Meta

  @draft "https://json-schema.org/draft/2020-12/schema"

  @spec encode(Zoi.Type.t()) :: map()
  def encode(schema) do
    schema
    |> encode_schema()
    |> add_dialect()
  end

  defp add_dialect(encoded_schema) do
    Map.put(encoded_schema, :"$schema", @draft)
  end

  defp encode_schema(%Zoi.Types.String{} = schema) do
    %{type: :string}
    |> encode_refinements(schema.meta)
  end

  defp encode_schema(%Zoi.Types.Integer{} = schema) do
    %{type: :integer}
    |> encode_refinements(schema.meta)
  end

  defp encode_schema(%Zoi.Types.Float{} = schema) do
    %{type: :number}
    |> encode_refinements(schema.meta)
  end

  defp encode_schema(%Zoi.Types.Number{} = schema) do
    %{type: :number}
    |> encode_refinements(schema.meta)
  end

  defp encode_schema(%Zoi.Types.Boolean{}) do
    %{type: :boolean}
  end

  defp encode_schema(%Zoi.Types.Literal{value: value}) do
    %{
      const: value
    }
  end

  defp encode_schema(%Zoi.Types.Null{}) do
    %{type: :null}
  end

  defp encode_schema(%Zoi.Types.Array{inner: inner} = schema) do
    case inner do
      %Zoi.Types.Any{} ->
        %{
          type: :array
        }
        |> encode_refinements(schema.meta)

      _inner ->
        %{
          type: :array,
          items: encode_schema(inner)
        }
        |> encode_refinements(schema.meta)
    end
  end

  defp encode_schema(%Zoi.Types.Tuple{} = schema) do
    %{
      type: :array,
      prefixItems: Enum.map(schema.fields, &encode_schema/1)
    }
    |> encode_refinements(schema.meta)
  end

  defp encode_schema(%Zoi.Types.Enum{} = schema) do
    %{
      type: :string,
      enum: Enum.map(schema.values, fn {_k, v} -> v end)
    }
  end

  defp encode_schema(%Zoi.Types.Map{}) do
    %{
      type: :object
    }
  end

  defp encode_schema(%Zoi.Types.Object{} = schema) do
    %{
      type: :object,
      properties:
        Enum.into(schema.fields, %{}, fn {key, value} ->
          {key, encode_schema(value)}
        end),
      required:
        Enum.filter(schema.fields, fn {_k, v} -> Meta.required?(v.meta) end)
        |> Enum.map(fn {k, _v} -> k end),
      additionalProperties: false
    }
  end

  defp encode_schema(%Zoi.Types.Intersection{schemas: schemas}) do
    %{
      allOf: Enum.map(schemas, &encode_schema/1)
    }
  end

  defp encode_schema(%Zoi.Types.Union{schemas: schemas}) do
    %{
      anyOf: Enum.map(schemas, &encode_schema/1)
    }
  end

  defp encode_schema(schema) do
    raise "Encoding not implemented for schema: #{inspect(schema)}"
  end

  defp encode_refinements(encoded_schema, %Meta{refinements: []}), do: encoded_schema

  defp encode_refinements(encoded_schema, %Meta{refinements: refinements}) do
    # Separate regex refinements from others
    {regex_refinements, other_refinements} =
      Enum.split_with(refinements, fn
        {_module, :refine, [[regex: _regex], _opts]} -> true
        _ -> false
      end)

    encoded_schema
    |> encode_length_refinements(other_refinements)
    |> encode_regex_refinements(regex_refinements)
  end

  defp encode_regex_refinements(json_schema, []), do: json_schema

  defp encode_regex_refinements(%{type: :string} = json_schema, [
         {_module, :refine, [[regex: regex], opts]}
       ]) do
    Keyword.fetch(opts, :format)
    |> case do
      {:ok, format} ->
        Map.merge(json_schema, %{format: format, pattern: regex})

      :error ->
        Map.put(json_schema, :pattern, regex)
    end
  end

  defp encode_regex_refinements(json_schema, regex_refinements) do
    patterns =
      Enum.map(regex_refinements, fn {_module, :refine, [[regex: regex], _opts]} -> regex end)

    Map.put(json_schema, :allOf, Enum.map(patterns, fn pattern -> %{pattern: pattern} end))
  end

  defp encode_length_refinements(json_schema, []), do: json_schema

  defp encode_length_refinements(json_schema, refinements) do
    Enum.reduce(refinements, json_schema, fn
      {_module, :refine, [func_param, _opts]}, acc ->
        length_to_json_schema(acc, func_param)

      _, acc ->
        acc
    end)
  end

  defp length_to_json_schema(json_schema, param) do
    case json_schema do
      %{type: :string} ->
        string_length_to_json_schema(json_schema, param)

      %{type: :number} ->
        numeric_length_to_json_schema(json_schema, param)

      %{type: :integer} ->
        numeric_length_to_json_schema(json_schema, param)

      %{type: :array} ->
        array_length_to_json_schema(json_schema, param)
    end
  end

  defp string_length_to_json_schema(json_schema, param) do
    case param do
      [gt: gt] ->
        Map.put(json_schema, :minLength, gt + 1)

      [gte: gte] ->
        Map.put(json_schema, :minLength, gte)

      [lt: lt] ->
        Map.put(json_schema, :maxLength, lt - 1)

      [lte: lte] ->
        Map.put(json_schema, :maxLength, lte)

      [length: length] ->
        json_schema
        |> Map.put(:minLength, length)
        |> Map.put(:maxLength, length)

      _ ->
        json_schema
    end
  end

  defp numeric_length_to_json_schema(json_schema, param) do
    case param do
      [gt: gt] ->
        Map.put(json_schema, :exclusiveMinimum, gt)

      [gte: gte] ->
        Map.put(json_schema, :minimum, gte)

      [lt: lt] ->
        Map.put(json_schema, :exclusiveMaximum, lt)

      [lte: lte] ->
        Map.put(json_schema, :maximum, lte)

        # _ ->
        # # No other refinements exist for numbers
        # json_schema
    end
  end

  defp array_length_to_json_schema(json_schema, param) do
    case param do
      [gt: gt] ->
        Map.put(json_schema, :minItems, gt + 1)

      [gte: gte] ->
        Map.put(json_schema, :minItems, gte)

      [lt: lt] ->
        Map.put(json_schema, :maxItems, lt - 1)

      [lte: lte] ->
        Map.put(json_schema, :maxItems, lte)

      [length: length] ->
        json_schema
        |> Map.put(:minItems, length)
        |> Map.put(:maxItems, length)

        # _ ->
        # # No other refinements exist for arrays
        # json_schema
    end
  end
end
