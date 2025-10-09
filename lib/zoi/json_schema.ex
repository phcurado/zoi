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

  - Refinements and custom validations defined in `Zoi` are not represented in the JSON Schema output. This is a limitation that will be addressed in future updates.
  - Complex types or custom types not listed above will raise an error during conversion.

  ## References

  - [JSON Schema Official Website](https://json-schema.org/)
  """

  alias Zoi.Types.Meta

  @spec encode(Zoi.Type.t()) :: map()
  def encode(schema) do
    schema
    |> encode_schema()
    |> add_dialect()
  end

  defp add_dialect(encoded_schema) do
    Map.put(encoded_schema, :"$schema", "https://json-schema.org/draft/2020-12/schema")
  end

  defp encode_schema(%Zoi.Types.String{} = schema) do
    %{type: :string}
    |> encode_refinements(schema.meta)
  end

  defp encode_schema(%Zoi.Types.Integer{}) do
    %{type: :integer}
  end

  defp encode_schema(%Zoi.Types.Float{}) do
    %{type: :number}
  end

  defp encode_schema(%Zoi.Types.Number{}) do
    %{type: :number}
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

  defp encode_schema(%Zoi.Types.Array{inner: inner}) do
    case inner do
      %Zoi.Types.Any{} ->
        %{
          type: :array
        }

      _inner ->
        %{
          type: :array,
          items: encode_schema(inner)
        }
    end
  end

  defp encode_schema(%Zoi.Types.Tuple{} = schema) do
    %{
      type: :array,
      prefixItems: Enum.map(schema.fields, &encode_schema/1)
    }
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
    # Note: Currently, only regex refinements are encoded into JSON Schema.
    # Needs to be improved to cover more refinement types.
    # Needs to manage aggregated data (multiple regexes) to use AnyOf/AllOf/OneOf
    Enum.reduce(refinements, encoded_schema, fn
      {_module, :refine, [[regex: regex], opts]}, acc ->
        Keyword.fetch(opts, :format)
        |> case do
          {:ok, format} ->
            Map.merge(acc, %{format: format, pattern: regex})

          :error ->
            Map.put(acc, :pattern, regex)
        end

      _, acc ->
        acc
    end)
  end
end
