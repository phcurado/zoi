defmodule Zoi.JSONSchemaTest do
  use ExUnit.Case, async: true
  # doctest Zoi.JSONSchema

  alias Zoi.Regexes

  @draft "https://json-schema.org/draft/2020-12/schema"

  describe "Zoi.to_json_schema/1" do
    test "different schemas to json" do
      schemas = [
        {Zoi.string(), %{type: :string}},
        {Zoi.integer(), %{type: :integer}},
        {Zoi.float(), %{type: :number}},
        {Zoi.number(), %{type: :number}},
        {Zoi.decimal(), %{type: :number}},
        {Zoi.boolean(), %{type: :boolean}},
        {Zoi.literal("fixed"), %{const: "fixed"}},
        {Zoi.null(), %{type: :null}},
        {Zoi.array(Zoi.integer()), %{type: :array, items: %{type: :integer}}},
        {Zoi.array(), %{type: :array}},
        {Zoi.tuple({Zoi.string(), Zoi.integer()}),
         %{type: :array, prefixItems: [%{type: :string}, %{type: :integer}]}},
        {Zoi.enum(["red", "green", "blue"]), %{type: :string, enum: ["red", "green", "blue"]}},
        {Zoi.map(), %{type: :object}},
        {Zoi.intersection([Zoi.string(), Zoi.literal("fixed")]),
         %{allOf: [%{type: :string}, %{const: "fixed"}]}},
        {Zoi.union([Zoi.string(), Zoi.integer()]),
         %{anyOf: [%{type: :string}, %{type: :integer}]}},
        {Zoi.nullable(Zoi.integer()), %{anyOf: [%{type: :null}, %{type: :integer}]}}
      ]

      Enum.each(schemas, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
    end

    test "enconding object" do
      schema =
        Zoi.object(%{name: Zoi.string(), age: Zoi.integer(), valid: Zoi.optional(Zoi.boolean())})

      assert %{
               "$schema": "https://json-schema.org/draft/2020-12/schema",
               type: :object,
               properties: %{
                 name: %{type: :string},
                 age: %{type: :integer},
                 valid: %{type: :boolean}
               },
               required: required_properties,
               additionalProperties: false
             } = Zoi.to_json_schema(schema)

      assert :name in required_properties
      assert :age in required_properties
    end

    test "encoding nested object" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{id: Zoi.integer(), email: Zoi.string()}),
          address:
            Zoi.object(%{
              street: Zoi.string(),
              city: Zoi.string(),
              zip: Zoi.string()
            }),
          tags:
            Zoi.array(
              Zoi.object(%{
                name: Zoi.string() |> Zoi.trim(),
                value: Zoi.string()
              })
            )
        })

      assert %{
               "$schema": "https://json-schema.org/draft/2020-12/schema",
               type: :object,
               properties: %{
                 user: %{
                   type: :object,
                   properties: %{
                     id: %{type: :integer},
                     email: %{type: :string}
                   },
                   required: required_user_properties,
                   additionalProperties: false
                 },
                 address: %{
                   type: :object,
                   properties: %{
                     street: %{type: :string},
                     city: %{type: :string},
                     zip: %{type: :string}
                   },
                   required: required_address_properties,
                   additionalProperties: false
                 },
                 tags: %{
                   type: :array,
                   items: %{
                     type: :object,
                     properties: %{
                       name: %{type: :string},
                       value: %{type: :string}
                     },
                     required: required_tag_properties,
                     additionalProperties: false
                   }
                 }
               },
               required: required_schema_properties,
               additionalProperties: false
             } = Zoi.to_json_schema(schema)

      Enum.each([:id, :email], fn prop ->
        assert prop in required_user_properties
      end)

      Enum.each([:street, :city, :zip], fn prop ->
        assert prop in required_address_properties
      end)

      Enum.each([:name, :value], fn prop ->
        assert prop in required_tag_properties
      end)

      Enum.each([:user, :address, :tags], fn prop ->
        assert prop in required_schema_properties
      end)
    end

    test "raise if schema is not supported" do
      assert_raise RuntimeError,
                   "Encoding not implemented for schema: #Zoi.atom<>",
                   fn ->
                     Zoi.to_json_schema(Zoi.atom())
                   end
    end

    @string_patterns [
      {"email", Zoi.email(), %{type: :string, format: :email, pattern: Regexes.email().source}},
      {"multiple regex", Zoi.email() |> Zoi.regex(~r/@example\.com$/),
       %{
         type: :string,
         allOf: [%{pattern: Regexes.email().source}, %{pattern: "@example\\.com$"}]
       }},
      {"min max length", Zoi.string() |> Zoi.min(3) |> Zoi.max(10),
       %{type: :string, minLength: 3, maxLength: 10}},
      {"exact length", Zoi.string() |> Zoi.length(5),
       %{type: :string, minLength: 5, maxLength: 5}},
      {"uuid", Zoi.uuid(), %{type: :string, pattern: Regexes.uuid().source}},
      {"url", Zoi.url(), %{type: :string, format: :uri}},
      {"lt gt", Zoi.string() |> Zoi.lt(10) |> Zoi.gt(3),
       %{type: :string, maxLength: 9, minLength: 4}},
      {"starts_with have no effect", Zoi.string() |> Zoi.starts_with("prefix"), %{type: :string}},
      {"custom refinement", Zoi.string() |> Zoi.refine({__MODULE__, :custom_refinemnet, []}),
       %{type: :string}}
    ]

    for {test_ref, schema, expected} <- @string_patterns do
      @schema schema
      @expected expected
      test "encoding #{test_ref} pattern" do
        expected = Map.put(@expected, :"$schema", @draft)
        assert Zoi.to_json_schema(@schema) == expected
      end
    end

    test "encoding string refinements with transforms" do
      schema =
        Zoi.string()
        |> Zoi.trim()
        |> Zoi.min(3)
        |> Zoi.max(5)

      assert %{
               "$schema": @draft,
               type: :string,
               minLength: 3,
               maxLength: 5
             } = Zoi.to_json_schema(schema)
    end

    @number_ranges [
      {"integer min max", Zoi.integer() |> Zoi.min(3) |> Zoi.max(10),
       %{type: :integer, minimum: 3, maximum: 10}},
      {"integer exclusive min max", Zoi.integer() |> Zoi.gt(3) |> Zoi.lt(10),
       %{type: :integer, exclusiveMinimum: 3, exclusiveMaximum: 10}},
      {"number min max", Zoi.number() |> Zoi.min(3.5) |> Zoi.max(10.5),
       %{type: :number, minimum: 3.5, maximum: 10.5}},
      {"number exclusive min max", Zoi.number() |> Zoi.gt(3.5) |> Zoi.lt(10.5),
       %{type: :number, exclusiveMinimum: 3.5, exclusiveMaximum: 10.5}}
    ]
    for {test_ref, schema, expected} <- @number_ranges do
      @schema schema
      @expected expected
      test "encoding #{test_ref} range" do
        expected = Map.put(@expected, :"$schema", @draft)
        assert Zoi.to_json_schema(@schema) == expected
      end
    end

    @decimal_ranges [
      {"decimal min max", Zoi.decimal() |> Zoi.min(3.5) |> Zoi.max(10.5),
       %{type: :number, minimum: 3.5, maximum: 10.5}},
      {"decimal exclusive min max", Zoi.decimal() |> Zoi.gt(3.5) |> Zoi.lt(10.5),
       %{type: :number, exclusiveMinimum: 3.5, exclusiveMaximum: 10.5}}
    ]
    for {test_ref, schema, expected} <- @decimal_ranges do
      @schema schema
      @expected expected
      test "encoding #{test_ref} range" do
        expected = Map.put(@expected, :"$schema", @draft)
        assert Zoi.to_json_schema(@schema) == expected
      end
    end

    @array_lengths [
      {"array min max", Zoi.array(Zoi.integer()) |> Zoi.min(2) |> Zoi.max(5),
       %{type: :array, items: %{type: :integer}, minItems: 2, maxItems: 5}},
      {"array exact length", Zoi.array(Zoi.integer()) |> Zoi.length(3),
       %{type: :array, items: %{type: :integer}, minItems: 3, maxItems: 3}},
      {"array gt lt", Zoi.array(Zoi.integer()) |> Zoi.gt(2) |> Zoi.lt(5),
       %{type: :array, items: %{type: :integer}, minItems: 3, maxItems: 4}},
      {"tuple min max", Zoi.tuple({Zoi.string(), Zoi.integer()}) |> Zoi.min(2) |> Zoi.max(4),
       %{
         type: :array,
         prefixItems: [%{type: :string}, %{type: :integer}],
         minItems: 2,
         maxItems: 4
       }},
      {"tuple exact length", Zoi.tuple({Zoi.string(), Zoi.integer()}) |> Zoi.length(2),
       %{
         type: :array,
         prefixItems: [%{type: :string}, %{type: :integer}],
         minItems: 2,
         maxItems: 2
       }}
    ]

    for {test_ref, schema, expected} <- @array_lengths do
      @schema schema
      @expected expected
      test "encoding #{test_ref} length" do
        expected = Map.put(@expected, :"$schema", @draft)
        assert Zoi.to_json_schema(@schema) == expected
      end
    end

    test "encoding array opts min/max items" do
      schema = Zoi.array(Zoi.integer(), min_length: 2, max_length: 4)

      assert %{
               "$schema": @draft,
               type: :array,
               items: %{type: :integer},
               minItems: 2,
               maxItems: 4
             } = Zoi.to_json_schema(schema)
    end

    test "encoding array opts exact length" do
      schema = Zoi.array(Zoi.integer(), length: 3)

      assert %{
               "$schema": @draft,
               type: :array,
               items: %{type: :integer},
               minItems: 3,
               maxItems: 3
             } = Zoi.to_json_schema(schema)
    end

    @date_schemas [
      {"date", Zoi.date(), %{type: :string, format: :date}},
      {"time", Zoi.time(), %{type: :string, format: :time}},
      {"datetime", Zoi.datetime(), %{type: :string, format: :"date-time"}},
      {"naive_datetime", Zoi.naive_datetime(), %{type: :string, format: :"date-time"}},
      {"iso date", Zoi.ISO.date(), %{type: :string, format: :date}},
      {"iso time", Zoi.ISO.time(), %{type: :string, format: :time}},
      {"iso datetime", Zoi.ISO.datetime(), %{type: :string, format: :"date-time"}},
      {"iso naive_datetime", Zoi.ISO.naive_datetime(), %{type: :string, format: :"date-time"}}
    ]
    for {test_ref, schema, expected} <- @date_schemas do
      @schema schema
      @expected expected
      test "encoding #{test_ref} schema" do
        expected = Map.put(@expected, :"$schema", @draft)
        assert Zoi.to_json_schema(@schema) == expected
      end
    end

    test "length in map type have no effect" do
      schema = Zoi.map() |> Zoi.length(3)
      expected = %{type: :object}
      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "parse schema description and example" do
      schema =
        Zoi.string(
          description: "This is a string",
          example: "Hello World"
        )

      expected = %{
        type: :string,
        description: "This is a string",
        example: "Hello World"
      }

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "parse schema metadata" do
      schema =
        Zoi.string(
          metadata: [
            description: "This is a string",
            example: "Hello World",
            not_used_metadata: 123
          ]
        )

      expected = %{
        type: :string,
        description: "This is a string",
        example: "Hello World"
      }

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "prioritize direct options over metadata" do
      schema =
        Zoi.string(
          description: "Direct description",
          example: "Direct example",
          metadata: [
            description: "Metadata description",
            example: "Metadata example"
          ]
        )

      expected = %{
        type: :string,
        description: "Direct description",
        example: "Direct example"
      }

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end
  end

  def custom_refinement(value) do
    if value == "valid" do
      :ok
    else
      {:error, "must be valid"}
    end
  end
end
