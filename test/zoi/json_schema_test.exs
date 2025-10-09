defmodule Zoi.JSONSchemaTest do
  use ExUnit.Case, async: true

  alias Zoi.JSONSchema

  describe "encode/1" do
    @schemas_and_expected_outputs [
      {"string", Zoi.string(), %{type: :string}},
      {"integer", Zoi.integer(), %{type: :integer}},
      {"number", Zoi.number(), %{type: :number}},
      {"boolean", Zoi.boolean(), %{type: :boolean}},
      {"literal", Zoi.literal("fixed"), %{const: "fixed"}},
      {"null", Zoi.null(), %{type: :null}},
      {"array", Zoi.array(Zoi.integer()), %{type: :array, items: %{type: :integer}}},
      {"any array", Zoi.array(), %{type: :array}},
      {"tuple", Zoi.tuple({Zoi.string(), Zoi.integer()}),
       %{type: :array, prefixItems: [%{type: :string}, %{type: :integer}]}},
      {"enum", Zoi.enum(["red", "green", "blue"]),
       %{type: :string, enum: ["red", "green", "blue"]}},
      {"any object", Zoi.map(), %{type: :object}},
      {"object",
       Zoi.object(%{name: Zoi.string(), age: Zoi.integer(), valid: Zoi.optional(Zoi.boolean())}),
       %{
         type: :object,
         properties: %{name: %{type: :string}, age: %{type: :integer}, valid: %{type: :boolean}},
         required: [:name, :age],
         additionalProperties: false
       }},
      {"intersection", Zoi.intersection([Zoi.string(), Zoi.literal("fixed")]),
       %{allOf: [%{type: :string}, %{const: "fixed"}]}},
      {"union", Zoi.union([Zoi.string(), Zoi.integer()]),
       %{anyOf: [%{type: :string}, %{type: :integer}]}}
    ]

    for {test_ref, schema, expected} <- @schemas_and_expected_outputs do
      @schema schema
      @expected expected
      test "encoding #{test_ref}" do
        expected = Map.put(@expected, :"$schema", "https://json-schema.org/draft/2020-12/schema")
        assert JSONSchema.encode(@schema) == expected
      end
    end
  end
end
