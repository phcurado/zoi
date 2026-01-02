defmodule Zoi.JSONSchema do
  @moduledoc """
  [JSON Schema](https://json-schema.org/) is a declarative language for annotating and validating JSON document's structure, constraints, and data types. It helps you standardize and define expectations for JSON data.

  `Zoi` provides functionality to convert its type definitions into JSON Schema format, enabling seamless integration with systems that utilize JSON Schema for data validation and documentation.

  ## Example

      iex> schema = Zoi.map(%{name: Zoi.string(), age: Zoi.integer()})
      iex> Zoi.to_json_schema(schema)
      %{
        "$schema": "https://json-schema.org/draft/2020-12/schema",
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
    - `Zoi.decimal/0` - (converted to JSON Schema `number`)
    - `Zoi.boolean/0`
    - `Zoi.literal/1`
    - `Zoi.null/0`
    - `Zoi.array/1`
    - `Zoi.tuple/1`
    - `Zoi.enum/1`
    - `Zoi.map/2`
    - `Zoi.intersection/1`
    - `Zoi.union/1`
    - `Zoi.nullable/1`
    - `Zoi.date/0` and `Zoi.ISO.date/0`
    - `Zoi.datetime/0` and `Zoi.ISO.datetime/0`
    - `Zoi.naive_datetime/0` and `Zoi.ISO.naive_datetime/0`
    - `Zoi.time/0` and `Zoi.ISO.time/0`

  ## Metadata
  `Zoi.to_json_schema/1` can also incorporate `description` and `example` metadata into the resulting JSON Schema:

  ```elixir
  iex> schema = Zoi.string(description: "A simple string", example: "Hello, World!")
  iex> Zoi.to_json_schema(schema)
  %{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    type: :string,
    description: "A simple string",
    example: "Hello, World!"
  }
  ```

  ## Limitations

  - Complex types or custom types not listed above will raise an error during conversion.
  - Some advanced `Zoi` features may not have direct equivalents in JSON Schema.
  - Refinements are partially supported, primarily for string patterns and length constraints.
  - Additional properties in objects are disallowed by default (`additionalProperties: false`).

  ## References

  - [JSON Schema Official Website](https://json-schema.org/)
  """

  alias Zoi.JSONSchema.Encoder

  @draft "https://json-schema.org/draft/2020-12/schema"

  @spec encode(Zoi.schema()) :: map()
  def encode(schema) do
    schema
    |> encode_schema()
    |> add_dialect()
  end

  @doc false
  @spec encode_schema(Zoi.schema()) :: map()
  def encode_schema(schema) do
    schema
    |> Encoder.encode()
    |> encode_metadata(schema)
    |> encode_refinements(schema)
  end

  defp add_dialect(encoded_schema) do
    Map.put(encoded_schema, :"$schema", @draft)
  end

  defp encode_refinements(encoded_schema, schema) do
    effect_refinements =
      Enum.flat_map(schema.meta.effects, fn
        {:refine, refinement} -> [refinement]
        {:transform, _transform} -> []
      end)

    {regex_refinements, other_refinements} =
      Enum.split_with(effect_refinements, fn
        {Zoi.Validations.Regex, :validate, _} -> true
        _ -> false
      end)

    other_refinements
    |> Enum.reduce(encoded_schema, &encode_refinement/2)
    |> encode_regex_refinements(regex_refinements)
  end

  # String refinements from effects

  defp encode_refinement(
         {Zoi.Validations.Gte, :validate, [value, _opts]},
         %{type: :string} = json_schema
       ) do
    Map.put(json_schema, :minLength, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Lte, :validate, [value, _opts]},
         %{type: :string} = json_schema
       ) do
    Map.put(json_schema, :maxLength, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Length, :validate, [value, _opts]},
         %{type: :string} = json_schema
       ) do
    json_schema
    |> Map.put(:minLength, value)
    |> Map.put(:maxLength, value)
  end

  # Numeric refinements from effects (integer and number)

  defp encode_refinement(
         {Zoi.Validations.Gte, :validate, [value, _opts]},
         %{type: type} = json_schema
       )
       when type in [:integer, :number] do
    Map.put(json_schema, :minimum, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Gt, :validate, [value, _opts]},
         %{type: type} = json_schema
       )
       when type in [:integer, :number] do
    Map.put(json_schema, :exclusiveMinimum, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Lte, :validate, [value, _opts]},
         %{type: type} = json_schema
       )
       when type in [:integer, :number] do
    Map.put(json_schema, :maximum, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Lt, :validate, [value, _opts]},
         %{type: type} = json_schema
       )
       when type in [:integer, :number] do
    Map.put(json_schema, :exclusiveMaximum, value)
  end

  # Array refinements from effects

  defp encode_refinement(
         {Zoi.Validations.Gte, :validate, [value, _opts]},
         %{type: :array} = json_schema
       ) do
    Map.put(json_schema, :minItems, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Lte, :validate, [value, _opts]},
         %{type: :array} = json_schema
       ) do
    Map.put(json_schema, :maxItems, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Length, :validate, [value, _opts]},
         %{type: :array} = json_schema
       ) do
    json_schema
    |> Map.put(:minItems, value)
    |> Map.put(:maxItems, value)
  end

  defp encode_refinement(
         {Zoi.Validations.Url, :validate, [_opts]},
         %{type: :string} = json_schema
       ) do
    Map.put(json_schema, :format, :uri)
  end

  defp encode_refinement(_refinement, json_schema) do
    json_schema
  end

  defp encode_regex_refinements(json_schema, []), do: json_schema

  defp encode_regex_refinements(%{type: :string} = json_schema, [
         {Zoi.Validations.Regex, :validate, [regex, _regex_opts, opts]}
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
      Enum.map(regex_refinements, fn {Zoi.Validations.Regex, :validate,
                                      [regex, _regex_opts, _opts]} ->
        regex
      end)

    Map.put(json_schema, :allOf, Enum.map(patterns, fn pattern -> %{pattern: pattern} end))
  end

  defp encode_metadata(json_schema, zoi_schema) do
    json_schema =
      json_schema
      |> maybe_add_metadata(:description, Zoi.description(zoi_schema))
      |> maybe_add_metadata(:example, Zoi.example(zoi_schema))

    Enum.reduce(Zoi.metadata(zoi_schema), json_schema, fn
      {:description, description}, acc ->
        Map.put_new(acc, :description, description)

      {:example, example}, acc ->
        Map.put_new(acc, :example, example)

      _, acc ->
        acc
    end)
  end

  defp maybe_add_metadata(json_schema, key, value) do
    if value do
      Map.put(json_schema, key, value)
    else
      json_schema
    end
  end
end
