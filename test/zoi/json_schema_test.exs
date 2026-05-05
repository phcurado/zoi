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
        {Zoi.nullable(Zoi.integer()), %{anyOf: [%{type: :null}, %{type: :integer}]}},
        {Zoi.lazy(fn -> Zoi.string() end), %{type: :string}},
        {Zoi.lazy({__MODULE__, :mfa_string_schema, []}), %{type: :string}},
        {Zoi.string() |> Zoi.default("hello"), %{type: :string, default: "hello"}}
      ]

      Enum.each(schemas, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
    end

    test "enconding object" do
      schema =
        Zoi.map(%{name: Zoi.string(), age: Zoi.integer(), valid: Zoi.optional(Zoi.boolean())})

      assert %{
               "$schema": "https://json-schema.org/draft/2020-12/schema",
               type: :object,
               properties: %{
                 name: %{type: :string},
                 age: %{type: :integer},
                 valid: %{type: :boolean}
               },
               required: required_properties,
               additionalProperties: true
             } = Zoi.to_json_schema(schema)

      assert :name in required_properties
      assert :age in required_properties
    end

    test "encoding strict object sets additionalProperties to false" do
      schema =
        Zoi.map(%{name: Zoi.string(), age: Zoi.integer()}, strict: true)

      assert %{
               "$schema": "https://json-schema.org/draft/2020-12/schema",
               type: :object,
               properties: %{
                 name: %{type: :string},
                 age: %{type: :integer}
               },
               required: _required_properties,
               additionalProperties: false
             } = Zoi.to_json_schema(schema)
    end

    test "encoding nested string patterns and refinements" do
      schema =
        Zoi.map(%{
          uuid: Zoi.uuid(),
          name: Zoi.string(),
          email: Zoi.email()
        })

      result = Zoi.to_json_schema(schema)

      uuid_pattern = Regexes.uuid().source
      email_pattern = Regexes.email().source

      assert %{
               "$schema": @draft,
               type: :object,
               properties: %{
                 uuid: %{type: :string, pattern: ^uuid_pattern},
                 name: %{type: :string},
                 email: %{type: :string, format: :email, pattern: ^email_pattern}
               },
               required: required_properties,
               additionalProperties: true
             } = result

      assert :uuid in required_properties
      assert :name in required_properties
      assert :email in required_properties
    end

    test "encoding nested object" do
      schema =
        Zoi.map(%{
          user: Zoi.map(%{id: Zoi.integer(), email: Zoi.string()}),
          address:
            Zoi.map(%{
              street: Zoi.string(),
              city: Zoi.string(),
              zip: Zoi.string()
            }),
          tags:
            Zoi.array(
              Zoi.map(%{
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
                   additionalProperties: true
                 },
                 address: %{
                   type: :object,
                   properties: %{
                     street: %{type: :string},
                     city: %{type: :string},
                     zip: %{type: :string}
                   },
                   required: required_address_properties,
                   additionalProperties: true
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
                     additionalProperties: true
                   }
                 }
               },
               required: required_schema_properties,
               additionalProperties: true
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
      assert_raise ArgumentError,
                   "Encoding not implemented for schema: #Zoi.atom<>",
                   fn ->
                     Zoi.to_json_schema(Zoi.atom())
                   end
    end

    test "string patterns and formats" do
      string_patterns = [
        {Zoi.email(), %{type: :string, format: :email, pattern: Regexes.email().source}},
        {Zoi.email() |> Zoi.regex(~r/@example\.com$/),
         %{
           type: :string,
           allOf: [%{pattern: Regexes.email().source}, %{pattern: "@example\\.com$"}]
         }},
        {Zoi.string() |> Zoi.min(3) |> Zoi.max(10),
         %{type: :string, minLength: 3, maxLength: 10}},
        {Zoi.string() |> Zoi.length(5), %{type: :string, minLength: 5, maxLength: 5}},
        {Zoi.uuid(), %{type: :string, pattern: Regexes.uuid().source}},
        {Zoi.url(), %{type: :string, format: :uri}},
        {Zoi.string() |> Zoi.lte(10) |> Zoi.gte(3),
         %{type: :string, maxLength: 10, minLength: 3}},
        {Zoi.string() |> Zoi.starts_with("prefix"), %{type: :string}},
        {Zoi.string() |> Zoi.refine({__MODULE__, :custom_refinemnet, []}), %{type: :string}}
      ]

      Enum.each(string_patterns, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
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

    test "numeric ranges" do
      number_ranges = [
        {Zoi.integer() |> Zoi.min(3) |> Zoi.max(10), %{type: :integer, minimum: 3, maximum: 10}},
        {Zoi.integer() |> Zoi.gt(3) |> Zoi.lt(10),
         %{type: :integer, exclusiveMinimum: 3, exclusiveMaximum: 10}},
        {Zoi.number() |> Zoi.min(3.5) |> Zoi.max(10.5),
         %{type: :number, minimum: 3.5, maximum: 10.5}},
        {Zoi.number() |> Zoi.gt(3.5) |> Zoi.lt(10.5),
         %{type: :number, exclusiveMinimum: 3.5, exclusiveMaximum: 10.5}},
        {Zoi.decimal() |> Zoi.min(3.5) |> Zoi.max(10.5),
         %{type: :number, minimum: 3.5, maximum: 10.5}},
        {Zoi.decimal() |> Zoi.gt(3.5) |> Zoi.lt(10.5),
         %{type: :number, exclusiveMinimum: 3.5, exclusiveMaximum: 10.5}},
        {Zoi.float() |> Zoi.min(3.5) |> Zoi.max(10.5),
         %{type: :number, minimum: 3.5, maximum: 10.5}},
        {Zoi.float() |> Zoi.gt(3.5) |> Zoi.lt(10.5),
         %{type: :number, exclusiveMinimum: 3.5, exclusiveMaximum: 10.5}}
      ]

      Enum.each(number_ranges, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
    end

    test "numeric ranges with transforms (effects-based refinements)" do
      # When a transform is applied first, constraints go through effects
      number_ranges = [
        {Zoi.integer() |> Zoi.transform(&(&1 * 2)) |> Zoi.min(3) |> Zoi.max(10),
         %{type: :integer, minimum: 3, maximum: 10}},
        {Zoi.integer() |> Zoi.transform(&(&1 * 2)) |> Zoi.gt(3) |> Zoi.lt(10),
         %{type: :integer, exclusiveMinimum: 3, exclusiveMaximum: 10}},
        {Zoi.number() |> Zoi.transform(&(&1 * 2)) |> Zoi.min(3.5) |> Zoi.max(10.5),
         %{type: :number, minimum: 3.5, maximum: 10.5}},
        {Zoi.number() |> Zoi.transform(&(&1 * 2)) |> Zoi.gt(3.5) |> Zoi.lt(10.5),
         %{type: :number, exclusiveMinimum: 3.5, exclusiveMaximum: 10.5}}
      ]

      Enum.each(number_ranges, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
    end

    test "array ranges" do
      array_lengths = [
        {Zoi.array(Zoi.integer()) |> Zoi.min(2) |> Zoi.max(5),
         %{type: :array, items: %{type: :integer}, minItems: 2, maxItems: 5}},
        {Zoi.array(Zoi.integer()) |> Zoi.length(3),
         %{type: :array, items: %{type: :integer}, minItems: 3, maxItems: 3}}
      ]

      Enum.each(array_lengths, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
    end

    test "array ranges with transforms (effects-based refinements)" do
      # When a transform is applied first, constraints go through effects
      array_lengths = [
        {Zoi.array(Zoi.integer()) |> Zoi.transform(&Enum.reverse/1) |> Zoi.min(2) |> Zoi.max(5),
         %{type: :array, items: %{type: :integer}, minItems: 2, maxItems: 5}},
        {Zoi.array(Zoi.integer()) |> Zoi.transform(&Enum.reverse/1) |> Zoi.length(3),
         %{type: :array, items: %{type: :integer}, minItems: 3, maxItems: 3}}
      ]

      Enum.each(array_lengths, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
    end

    test "string length with transform (effects-based refinement)" do
      schema =
        Zoi.string()
        |> Zoi.trim()
        |> Zoi.length(5)

      assert %{
               "$schema": @draft,
               type: :string,
               minLength: 5,
               maxLength: 5
             } = Zoi.to_json_schema(schema)
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

    test "date schemas" do
      date_schemas = [
        {Zoi.date(), %{type: :string, format: :date}},
        {Zoi.time(), %{type: :string, format: :time}},
        {Zoi.datetime(), %{type: :string, format: :"date-time"}},
        {Zoi.naive_datetime(), %{type: :string, format: :"date-time"}},
        {Zoi.ISO.date(), %{type: :string, format: :date}},
        {Zoi.ISO.time(), %{type: :string, format: :time}},
        {Zoi.ISO.datetime(), %{type: :string, format: :"date-time"}},
        {Zoi.ISO.naive_datetime(), %{type: :string, format: :"date-time"}}
      ]

      Enum.each(date_schemas, fn {schema, expected} ->
        expected = Map.put(expected, :"$schema", @draft)
        assert Zoi.to_json_schema(schema) == expected
      end)
    end

    test "date schemas with constraints" do
      min_date = ~D[2024-01-01]
      max_date = ~D[2024-12-31]

      schema = Zoi.date(gte: min_date, lte: max_date)

      assert %{
               "$schema": @draft,
               type: :string,
               format: :date,
               minimum: "2024-01-01",
               maximum: "2024-12-31"
             } = Zoi.to_json_schema(schema)
    end

    test "date schemas with exclusive constraints" do
      min_date = ~D[2024-01-01]
      max_date = ~D[2024-12-31]

      schema = Zoi.date(gt: min_date, lt: max_date)

      assert %{
               "$schema": @draft,
               type: :string,
               format: :date,
               exclusiveMinimum: "2024-01-01",
               exclusiveMaximum: "2024-12-31"
             } = Zoi.to_json_schema(schema)
    end

    test "time schemas with constraints" do
      min_time = ~T[09:00:00]
      max_time = ~T[17:00:00]

      schema = Zoi.time(gte: min_time, lte: max_time)

      assert %{
               "$schema": @draft,
               type: :string,
               format: :time,
               minimum: "09:00:00",
               maximum: "17:00:00"
             } = Zoi.to_json_schema(schema)
    end

    test "datetime schemas with constraints" do
      min_datetime = ~U[2024-01-01 00:00:00Z]
      max_datetime = ~U[2024-12-31 23:59:59Z]

      schema = Zoi.datetime(gte: min_datetime, lte: max_datetime)

      assert %{
               "$schema": @draft,
               type: :string,
               format: :"date-time",
               minimum: "2024-01-01T00:00:00Z",
               maximum: "2024-12-31T23:59:59Z"
             } = Zoi.to_json_schema(schema)
    end

    test "naive_datetime schemas with constraints" do
      min_datetime = ~N[2024-01-01 00:00:00]
      max_datetime = ~N[2024-12-31 23:59:59]

      schema = Zoi.naive_datetime(gte: min_datetime, lte: max_datetime)

      assert %{
               "$schema": @draft,
               type: :string,
               format: :"date-time",
               minimum: "2024-01-01T00:00:00",
               maximum: "2024-12-31T23:59:59"
             } = Zoi.to_json_schema(schema)
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

    test "parse schema deprecated" do
      schema = Zoi.string(deprecated: "Use another field")

      expected = %{
        type: :string,
        deprecated: true
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

    test "parse schema title" do
      schema = Zoi.string(title: "Username")

      expected = %{type: :string, title: "Username"}

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "parse schema examples list" do
      schema = Zoi.string(examples: ["alice", "bob"])

      expected = %{type: :string, examples: ["alice", "bob"]}

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "parse schema example and examples emit independently" do
      schema = Zoi.string(example: "alice", examples: ["alice", "bob"])

      expected = %{
        type: :string,
        example: "alice",
        examples: ["alice", "bob"]
      }

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "parse schema read_only" do
      schema = Zoi.string(read_only: true)

      expected = %{type: :string, readOnly: true}

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "parse schema write_only" do
      schema = Zoi.string(write_only: true)

      expected = %{type: :string, writeOnly: true}

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "read_only/write_only false are not emitted" do
      schema = Zoi.string(read_only: false, write_only: false)

      expected = %{type: :string}

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "parse schema id and comment" do
      schema =
        Zoi.string(
          id: "https://example.com/schemas/name",
          comment: "internal note"
        )

      expected = %{
        type: :string,
        "$id": "https://example.com/schemas/name",
        "$comment": "internal note"
      }

      assert Zoi.to_json_schema(schema) == Map.put(expected, :"$schema", @draft)
    end

    test "encoding discriminated_union" do
      cat_schema = Zoi.map(%{type: Zoi.literal("cat"), meow: Zoi.string()})
      dog_schema = Zoi.map(%{type: Zoi.literal("dog"), bark: Zoi.string()})
      schema = Zoi.discriminated_union(:type, [cat_schema, dog_schema])

      result = Zoi.to_json_schema(schema)

      assert %{
               "$schema": @draft,
               oneOf: [cat_json_schema, dog_json_schema],
               discriminator: %{
                 propertyName: "type"
               }
             } = result

      assert %{type: :object, properties: %{type: %{const: "cat"}, meow: %{type: :string}}} =
               cat_json_schema

      assert %{type: :object, properties: %{type: %{const: "dog"}, bark: %{type: :string}}} =
               dog_json_schema
    end
  end

  describe "Zoi.from_json_schema/1" do
    test "decodes primitive types" do
      cases = [
        {%{"type" => "string"}, "x"},
        {%{"type" => "integer"}, 1},
        {%{"type" => "number"}, 1.5},
        {%{"type" => "boolean"}, true},
        {%{"type" => "null"}, nil}
      ]

      Enum.each(cases, fn {json, value} ->
        schema = Zoi.from_json_schema(json)
        assert Zoi.parse(schema, value) == {:ok, value}
      end)
    end

    test "decodes literal, enum, and combinators" do
      cases = [
        {%{"const" => "fixed"}, "fixed", "other"},
        {%{"enum" => ["red", "green"]}, "red", "blue"},
        {%{"oneOf" => [%{"type" => "string"}, %{"type" => "integer"}]}, "x", true},
        {%{"anyOf" => [%{"type" => "string"}, %{"type" => "integer"}]}, 1, true},
        {%{"allOf" => [%{"type" => "string"}, %{"const" => "fixed"}]}, "fixed", "other"}
      ]

      Enum.each(cases, fn {json, valid, invalid} ->
        schema = Zoi.from_json_schema(json)
        assert Zoi.parse(schema, valid) == {:ok, valid}
        assert {:error, _} = Zoi.parse(schema, invalid)
      end)
    end

    test "decodes string formats with coercion" do
      cases = [
        {%{"type" => "string", "format" => "date"}, "2024-01-01", ~D[2024-01-01]},
        {%{"type" => "string", "format" => "time"}, "12:00:00", ~T[12:00:00]},
        {%{"type" => "string", "format" => "date-time"}, "2024-01-01T00:00:00Z",
         ~U[2024-01-01 00:00:00Z]},
        {%{"type" => "string", "format" => "email"}, "user@example.com", "user@example.com"},
        {%{"type" => "string", "format" => "uri"}, "https://example.com", "https://example.com"}
      ]

      Enum.each(cases, fn {json, input, expected} ->
        schema = Zoi.from_json_schema(json)
        assert Zoi.parse(schema, input) == {:ok, expected}
      end)
    end

    test "decodes constraints and rejects invalid values" do
      cases = [
        {%{"type" => "string", "minLength" => 2, "maxLength" => 5}, "abc",
         ["a", "abcdef"]},
        {%{"type" => "integer", "minimum" => 0, "maximum" => 10, "multipleOf" => 2}, 4,
         [-1, 11, 3]},
        {%{
           "type" => "array",
           "items" => %{"type" => "integer"},
           "minItems" => 1,
           "maxItems" => 3
         }, [1, 2], [[], [1, 2, 3, 4]]}
      ]

      Enum.each(cases, fn {json, valid, invalids} ->
        schema = Zoi.from_json_schema(json)
        assert Zoi.parse(schema, valid) == {:ok, valid}

        Enum.each(invalids, fn invalid ->
          assert {:error, _} = Zoi.parse(schema, invalid)
        end)
      end)
    end

    test "decodes tuple via prefixItems" do
      schema =
        Zoi.from_json_schema(%{
          "type" => "array",
          "prefixItems" => [%{"type" => "string"}, %{"type" => "integer"}]
        })

      assert Zoi.parse(schema, {"a", 1}) == {:ok, {"a", 1}}
    end

    test "decodes object with required, optional, and additionalProperties false" do
      json = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      schema = Zoi.from_json_schema(json)

      assert Zoi.parse(schema, %{"name" => "x", "age" => 1}) ==
               {:ok, %{"name" => "x", "age" => 1}}

      assert Zoi.parse(schema, %{"name" => "x"}) == {:ok, %{"name" => "x"}}
      assert {:error, _} = Zoi.parse(schema, %{"age" => 1})

      strict = Zoi.from_json_schema(Map.put(json, "additionalProperties", false))
      assert {:error, _} = Zoi.parse(strict, %{"name" => "x", "extra" => 1})
    end

    test "carries metadata into Zoi schema" do
      schema =
        Zoi.from_json_schema(%{
          "type" => "string",
          "title" => "Username",
          "description" => "Login name",
          "examples" => ["alice"],
          "readOnly" => true,
          "$id" => "https://example.com/name",
          "$comment" => "internal"
        })

      assert Zoi.title(schema) == "Username"
      assert Zoi.description(schema) == "Login name"
      assert Zoi.examples(schema) == ["alice"]
      assert Zoi.read_only?(schema) == true
      assert Zoi.id(schema) == "https://example.com/name"
      assert Zoi.comment(schema) == "internal"
    end

    test "default keyword wraps schema with Zoi.default" do
      schema = Zoi.from_json_schema(%{"type" => "string", "default" => "x"})
      assert Zoi.parse(schema, nil) == {:ok, "x"}
    end

    test "raises on non-map input" do
      assert_raise ArgumentError, fn -> Zoi.from_json_schema("nope") end
    end
  end

  def custom_refinement(value) do
    if value == "valid" do
      :ok
    else
      {:error, "must be valid"}
    end
  end

  def mfa_string_schema, do: Zoi.string()
end
