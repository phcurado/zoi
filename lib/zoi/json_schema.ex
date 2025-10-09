defmodule Zoi.JSONSchema do
  @moduledoc false

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

  defp encode_schema(%Zoi.Types.String{}) do
    %{type: :string}
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
end
