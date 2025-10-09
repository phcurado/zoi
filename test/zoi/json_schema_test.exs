defmodule Zoi.JSONSchemaTest do
  use ExUnit.Case, async: true

  alias Zoi.JSONSchema

  describe "encode/1" do
    @schemas_and_expected_outputs [
      {Zoi.string(), %{type: :string}},
      {Zoi.integer(), %{type: :integer}}
      # {Zoi.number(), %{type: :number}}
      # {Zoi.boolean(), %{type: :boolean}},
      # {Zoi.null(), %{type: :null}}
      # {Zoi.object(%{name: Zoi.string(), age: Zoi.integer()}), %{
      #   type: :object,
      #   properties: %{name: %{type: :string}, age: %{type: :integer}},
      #   required: [:name, :age],
      #   additionalProperties: false
      # }}
    ]

    for {schema, expected} <- @schemas_and_expected_outputs do
      @schema schema
      @expected expected
      test "encoding #{inspect(@expected.type)}" do
        expected = Map.put(@expected, :"$schema", "https://json-schema.org/draft/2020-12/schema")
        assert JSONSchema.encode(@schema) == expected
      end
    end

    # test "simple object schema" do
    #   schema = Zoi.object(%{name: Zoi.string(), age: Zoi.number()})
    #
    #   expected_schema = %{
    #     type: :object,
    #     properties: %{name: %{type: :string}, age: %{type: :number}},
    #     required: [:name, :age],
    #     additionalProperties: false
    #   }
    #
    #   assert JSONSchema.encode(schema) == expected_schema
    # end
  end
end
