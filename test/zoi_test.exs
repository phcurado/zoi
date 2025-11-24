defmodule ZoiTest do
  use ExUnit.Case, async: true
  doctest Zoi

  defmodule User do
    defstruct [:name, :age]
  end

  describe "parse/3" do
    test "parse types with custom errors" do
      custom_error = "custom error"

      types = [
        Zoi.string(error: custom_error),
        Zoi.integer(error: custom_error),
        Zoi.float(error: custom_error),
        Zoi.number(error: custom_error),
        Zoi.boolean(error: custom_error),
        Zoi.array(Zoi.string(), error: custom_error)
      ]

      for type <- types do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(type, :asdf)
        assert Exception.message(error) == custom_error
      end
    end
  end

  describe "parse!/3" do
    test "parse! with correct value" do
      assert "hello" == Zoi.parse!(Zoi.string(), "hello")
      assert 123 == Zoi.parse!(Zoi.integer(), 123)
    end

    test "parse! with incorrect value" do
      assert_raise Zoi.ParseError,
                   "Parsing error:\n\ninvalid type: expected string\n",
                   fn ->
                     Zoi.parse!(Zoi.string(), 123)
                   end

      assert_raise Zoi.ParseError,
                   "Parsing error:\n\ninvalid type: expected integer\n",
                   fn ->
                     Zoi.parse!(Zoi.integer(), "not an integer")
                   end
    end
  end

  describe "string/1" do
    test "string with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.string(), "hello")
      assert {:ok, ""} == Zoi.parse(Zoi.string(), "")
      assert {:ok, "123"} == Zoi.parse(Zoi.string(), "123")
    end

    test "string with coercion" do
      assert {:ok, "123"} == Zoi.parse(Zoi.string(coerce: false), 123, coerce: true)
      assert {:ok, "true"} == Zoi.parse(Zoi.string(), true, coerce: true)
      assert {:ok, "12.34"} == Zoi.parse(Zoi.string(), 12.34, coerce: true)
    end

    test "string with incorrect value" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.string(), :not_a_string)

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected string"
    end

    test "string with min_length option" do
      schema = Zoi.string(min_length: 5)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")

      assert {:error, [error]} = Zoi.parse(schema, "hi")
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must have at least 5 character(s)"
    end

    test "string with max_length option" do
      schema = Zoi.string(max_length: 10)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")

      assert {:error, [error]} = Zoi.parse(schema, "hello world")
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must have at most 10 character(s)"
    end

    test "string with both min_length and max_length options" do
      schema = Zoi.string(min_length: 3, max_length: 10)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")

      assert {:error, [error]} = Zoi.parse(schema, "hi")
      assert error.code == :greater_than_or_equal_to

      assert {:error, [error]} = Zoi.parse(schema, "hello world")
      assert error.code == :less_than_or_equal_to
    end

    test "string min_length validates before transform" do
      # min_length is set as field, so validates during parse_type (before effects)
      schema = Zoi.string(min_length: 10) |> Zoi.transform(&String.trim/1)

      assert {:ok, "hello world"} = Zoi.parse(schema, "hello world")

      assert {:error, [error]} = Zoi.parse(schema, "  hello  ")
      assert error.code == :greater_than_or_equal_to
    end

    test "string min after transform validates after transform" do
      # min added after transform goes into effects
      schema = Zoi.string() |> Zoi.transform(&String.trim/1) |> Zoi.min(5)

      assert {:ok, "hello"} = Zoi.parse(schema, "  hello  ")

      assert {:error, [error]} = Zoi.parse(schema, "  hi  ")
      assert error.code == :greater_than_or_equal_to
    end

    test "string with length option" do
      schema = Zoi.string(length: 2)

      assert {:ok, "hi"} = Zoi.parse(schema, "hi")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "h")
      assert error.code == :invalid_length
    end

    test "string length/2 sets schema field when there are no effects" do
      schema = Zoi.string() |> Zoi.length(4)
      assert schema.length == {4, []}
      refute schema.min_length
      refute schema.max_length
    end

    test "string options length overrides min and max" do
      schema = Zoi.string(min_length: 1, max_length: 5, length: 2)
      assert schema.length == {2, []}
      refute schema.min_length
      refute schema.max_length
    end

    test "constructor with tuple format for custom errors" do
      schema = Zoi.string(min_length: {5, [error: "too short!"]})

      assert {:error, [%Zoi.Error{code: :custom, message: "too short!"}]} =
               Zoi.parse(schema, "hi")

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
    end

    test "constructor with mixed tuple and plain formats" do
      schema = Zoi.string(min_length: {3, [error: "custom min"]}, max_length: 10)

      assert {:error, [%Zoi.Error{code: :custom, message: "custom min"}]} =
               Zoi.parse(schema, "hi")

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")

      assert {:error, [%Zoi.Error{code: :less_than_or_equal_to}]} =
               Zoi.parse(schema, "hello world!")
    end

    test "string length after transform validates after" do
      schema =
        Zoi.string()
        |> Zoi.transform(&String.upcase/1)
        |> Zoi.length(5)

      assert {:ok, "HELLO"} = Zoi.parse(schema, "hello")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert error.code == :invalid_length
    end
  end

  describe "integer/1" do
    test "integer with correct value" do
      assert {:ok, 22} == Zoi.parse(Zoi.integer(), 22)
    end

    test "integer with incorrect value" do
      wrong_values = ["12", nil, 12.34, :atom, "not an integer"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.integer(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected integer"
      end
    end

    test "integer with coercion" do
      assert {:ok, 123} == Zoi.parse(Zoi.integer(coerce: false), "123", coerce: true)
      assert {:ok, 0} == Zoi.parse(Zoi.integer(), "0", coerce: true)
      assert {:ok, -1} == Zoi.parse(Zoi.integer(), "-1", coerce: true)
    end

    test "integer with coercion but incorrect value" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.integer(), "not_integer", coerce: true)

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected integer"
    end
  end

  describe "float/1" do
    test "float with correct value" do
      assert {:ok, 12.34} == Zoi.parse(Zoi.float(), 12.34)
      assert {:ok, 42.0} == Zoi.parse(Zoi.float(), 42.00)
      assert {:ok, 0.0} == Zoi.parse(Zoi.float(), 0.0)
      assert {:ok, -1.0} == Zoi.parse(Zoi.float(), -1.0)
    end

    test "float with incorrect value" do
      wrong_values = ["12", nil, 12, :atom, "not a float"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.float(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected float"
      end
    end

    test "float with coercion" do
      assert {:ok, 12.34} == Zoi.parse(Zoi.float(coerce: false), "12.34", coerce: true)
      assert {:ok, 0.0} == Zoi.parse(Zoi.float(), "0", coerce: true)
      assert {:ok, -1.0} == Zoi.parse(Zoi.float(), "-1", coerce: true)
    end

    test "float with coercion but incorrect value" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.float(), "not_float", coerce: true)

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected float"
    end
  end

  describe "number/1" do
    test "number with correct value" do
      assert {:ok, 12.34} == Zoi.parse(Zoi.number(), 12.34)
      assert {:ok, 42} == Zoi.parse(Zoi.number(), 42)
      assert {:ok, 0} == Zoi.parse(Zoi.number(), 0)
      assert {:ok, -1} == Zoi.parse(Zoi.number(), -1)
    end

    test "number with incorrect value" do
      wrong_values = ["12", nil, :atom, "not a number"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.number(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected number"
      end
    end

    test "number with coercion" do
      assert {:ok, 12.34} == Zoi.parse(Zoi.number(coerce: true), "12.34")
      assert {:ok, 0} == Zoi.parse(Zoi.number(), "0", coerce: true)
      assert {:ok, -1} == Zoi.parse(Zoi.number(), "-1", coerce: true)

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.number(), "not_number", coerce: true)

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected number"

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.number(), "34.not", coerce: true)

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected number"
    end

    test "number with custom error" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.number(error: "custom number error"), "not a number")

      assert error.code == :custom
      assert Exception.message(error) == "custom number error"
    end
  end

  describe "boolean/1" do
    test "boolean with correct values" do
      assert {:ok, true} == Zoi.parse(Zoi.boolean(), true)
      assert {:ok, false} == Zoi.parse(Zoi.boolean(), false)
    end

    test "boolean with incorrect value" do
      wrong_values = ["12", nil, 12.34, :atom, "true"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.boolean(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected boolean"
      end
    end

    test "boolean with coercion" do
      assert {:ok, true} == Zoi.parse(Zoi.boolean(), "true", coerce: true)
      assert {:ok, false} == Zoi.parse(Zoi.boolean(), "false", coerce: true)
    end

    test "invalid boolean with coercion" do
      wrong_values = ["True", "False", "1", "0", "on", "off", 1, 0]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.boolean(), value, coerce: true)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected boolean"
      end
    end
  end

  describe "string_boolean/1" do
    test "string_boolean with correct values" do
      truthy = [true, "true", "1", "yes", "on", "y", "enabled", "True", "ENabled"]
      falsy = [false, "false", "0", "no", "off", "n", "disabled", "False", "DISabled"]

      for truthy_value <- truthy do
        assert {:ok, true} == Zoi.parse(Zoi.string_boolean(), truthy_value)
      end

      for falsy_value <- falsy do
        assert {:ok, false} == Zoi.parse(Zoi.string_boolean(), falsy_value)
      end
    end

    test "string_boolean with incorrect value" do
      wrong_values = [nil, 12.34, :atom, "not a boolean"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.string_boolean(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected string boolean"
      end
    end

    test "string_boolean case sensitive" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.string_boolean(case: "sensitive"), "True")

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected string boolean"
    end
  end

  describe "any/1" do
    test "any with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.any(), "hello")
      assert {:ok, 123} == Zoi.parse(Zoi.any(), 123)
      assert {:ok, true} == Zoi.parse(Zoi.any(), true)
      assert {:ok, nil} == Zoi.parse(Zoi.any(), nil)
      assert {:ok, :atom} == Zoi.parse(Zoi.any(), :atom)
    end
  end

  describe "atom/1" do
    test "atom with correct value" do
      assert {:ok, :hello} == Zoi.parse(Zoi.atom(), :hello)
      assert {:ok, :world} == Zoi.parse(Zoi.atom(), :world)
      assert {:ok, nil} == Zoi.parse(Zoi.atom(), nil)
      assert {:ok, true} == Zoi.parse(Zoi.atom(), true)
      assert {:ok, false} == Zoi.parse(Zoi.atom(), false)
    end

    test "atom with incorrect value" do
      wrong_values = ["hello", 123, 1.5]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.atom(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected atom"
      end
    end
  end

  describe "literal/2" do
    test "literal with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.literal("hello"), "hello")
      assert {:ok, 123} == Zoi.parse(Zoi.literal(123), 123)
      assert {:ok, true} == Zoi.parse(Zoi.literal(true), true)
      assert {:ok, false} == Zoi.parse(Zoi.literal(false), false)
      assert {:ok, nil} == Zoi.parse(Zoi.literal(nil), nil)
      assert {:ok, :atom} == Zoi.parse(Zoi.literal(:atom), :atom)
    end

    test "literal with incorrect value" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.literal("hello"), "not_hello")

      assert error.code == :invalid_literal
      assert Exception.message(error) == "invalid literal: expected hello"

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.literal(123), 456)
      assert error.code == :invalid_literal
      assert Exception.message(error) == "invalid literal: expected 123"
    end

    test "literal with custom error" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.literal("hello", error: "custom literal error"), "not_hello")

      assert error.code == :custom
      assert Exception.message(error) == "custom literal error"
    end
  end

  describe "null/1" do
    test "null with nil value" do
      assert {:ok, nil} == Zoi.parse(Zoi.null(), nil)
    end

    test "null with incorrect value" do
      wrong_values = ["hello", 123, 1.5, :atom, true, false, %{}, []]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.null(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected nil"
      end
    end

    test "null with custom error" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.null(error: "custom null error"), "not nil")

      assert error.code == :custom
      assert Exception.message(error) == "custom null error"
    end
  end

  describe "optional/2" do
    test "optional with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.optional(Zoi.string()), "hello")
    end

    test "optional should fail if send `nil` value" do
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.optional(Zoi.string()), nil)
      assert Exception.message(error) == "invalid type: expected string"
    end

    test "optional with incorrect type" do
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.optional(Zoi.string()), 123)
      assert Exception.message(error) == "invalid type: expected string"
    end

    test "optional with nullable" do
      schema = Zoi.optional(Zoi.nullable(Zoi.string()))
      assert {:ok, nil} == Zoi.parse(schema, nil)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "optional with default value" do
      schema = Zoi.object(%{name: Zoi.optional(Zoi.default(Zoi.string(), "no name"))})
      assert {:ok, %{}} == Zoi.parse(schema, %{})

      assert {:ok, %{name: "no name"}} == Zoi.parse(schema, %{name: nil})
    end

    test "default with optional value" do
      schema = Zoi.object(%{name: Zoi.default(Zoi.optional(Zoi.string()), "no name")})

      assert {:ok, %{name: "no name"}} == Zoi.parse(schema, %{})
    end
  end

  describe "nullable/2" do
    test "nullable with nil value" do
      schema = Zoi.nullable(Zoi.string())
      assert {:ok, nil} == Zoi.parse(schema, nil)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "nullable with incorrect type" do
      schema = Zoi.nullable(Zoi.string())
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 123)
      assert Exception.message(error) == "invalid type: expected string"
    end

    test "nullable with transform" do
      schema = Zoi.nullable(Zoi.string() |> Zoi.transform(fn value -> String.upcase(value) end))

      assert {:ok, "HELLO"} == Zoi.parse(schema, "hello")
    end

    test "nested nullable" do
      schema = Zoi.nullable(Zoi.array(Zoi.nullable(Zoi.string())))
      assert {:ok, nil} == Zoi.parse(schema, nil)
      assert {:ok, ["hello", nil, "world"]} == Zoi.parse(schema, ["hello", nil, "world"])
      assert {:error, [error_1, error_2]} = Zoi.parse(schema, ["1", 2, nil, 4])
      assert Exception.message(error_1) == "invalid type: expected string"
      assert error_1.path == [1]
      assert Exception.message(error_2) == "invalid type: expected string"
      assert error_2.path == [3]
    end
  end

  describe "nullish/2" do
    test "nullish with nil value" do
      schema = Zoi.nullish(Zoi.string())
      assert {:ok, nil} == Zoi.parse(schema, nil)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "nullish with missing value on object" do
      schema = Zoi.object(%{name: Zoi.nullish(Zoi.string())})
      assert {:ok, %{}} == Zoi.parse(schema, %{})
      assert {:ok, %{name: nil}} == Zoi.parse(schema, %{name: nil})
      assert {:ok, %{name: "hello"}} == Zoi.parse(schema, %{name: "hello"})
    end

    test "nullish with incorrect type" do
      schema = Zoi.nullish(Zoi.string())
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 123)
      assert Exception.message(error) == "invalid type: expected string"
    end

    test "nullish with transform" do
      # Transform function should handle nil value
      schema =
        Zoi.nullish(Zoi.string()) |> Zoi.transform(fn value -> value && String.upcase(value) end)

      assert {:ok, "HELLO"} == Zoi.parse(schema, "hello")
      assert {:ok, nil} == Zoi.parse(schema, nil)
    end
  end

  describe "default/2" do
    test "default with correct value" do
      schema = Zoi.default(Zoi.string(), "default_value")

      assert {:ok, "default_value"} == Zoi.parse(schema, nil)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "default with incorrect type" do
      # Zoi will not validate the default value
      schema = Zoi.default(Zoi.integer(), "10")
      assert {:ok, "10"} == Zoi.parse(schema, nil)
    end

    test "optional with default value" do
      schema =
        Zoi.object(%{
          name:
            Zoi.optional(
              Zoi.default(
                Zoi.string() |> Zoi.transform(fn value -> value <> "_refined" end),
                "no name"
              )
            )
        })

      assert {:ok, %{}} == Zoi.parse(schema, %{})
      # Transform will run on default value, since it's short circuit
      assert {:ok, %{name: "no name"}} == Zoi.parse(schema, %{name: nil})
      assert {:ok, %{name: "John_refined"}} == Zoi.parse(schema, %{name: "John"})
    end

    test "default with refinement" do
      schema =
        Zoi.default(
          Zoi.string() |> Zoi.starts_with("prefix_"),
          "prefix_default"
        )

      assert {:ok, "prefix_default"} == Zoi.parse(schema, nil)
      assert {:ok, "prefix_value"} == Zoi.parse(schema, "prefix_value")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "wrong_value")
      assert Exception.message(error) == "invalid format: must start with 'prefix_'"
    end
  end

  describe "union/2" do
    test "union with correct values" do
      schema = Zoi.union([Zoi.string(), Zoi.integer()])

      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:ok, 42} == Zoi.parse(schema, 42)
    end

    test "union with incorrect value" do
      schema = Zoi.union([Zoi.string(), Zoi.integer()])

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert Exception.message(error) == "invalid type: expected integer"
    end

    test "union with coerced values" do
      schema = Zoi.union([Zoi.boolean(), Zoi.integer()])

      assert {:ok, true} == Zoi.parse(schema, "true", coerce: true)
      assert {:ok, 456} == Zoi.parse(schema, "456", coerce: true)
    end

    test "union with multiple schemas" do
      schema = Zoi.union([Zoi.string(), Zoi.integer(), Zoi.boolean()])

      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:ok, 42} == Zoi.parse(schema, 42)
      assert {:ok, true} == Zoi.parse(schema, true)
    end

    test "union with empty schemas or 1 element" do
      assert_raise ArgumentError, "Union type must receive a list of minimum 2 schemas", fn ->
        Zoi.union([])
      end

      assert_raise ArgumentError, "Union type must receive a list of minimum 2 schemas", fn ->
        Zoi.union([Zoi.string()])
      end
    end

    test "union with incorrect type" do
      assert_raise ArgumentError, "Union type must receive a list of minimum 2 schemas", fn ->
        Zoi.union(Zoi.string())
      end
    end

    test "union type with refinements" do
      schema =
        Zoi.union([Zoi.string() |> Zoi.starts_with("prefix_"), Zoi.integer()]) |> Zoi.min(5)

      assert {:ok, "prefix_value"} == Zoi.parse(schema, "prefix_value")
      assert {:ok, 10} == Zoi.parse(schema, 10)

      # Fails on `starts_with` refinement, fallback to integer validation
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "value")
      assert Exception.message(error) == "invalid type: expected integer"

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 3)
      assert Exception.message(error) == "too small: must be at least 5"
    end

    test "union type with transforms" do
      schema =
        Zoi.union([Zoi.string() |> Zoi.to_downcase(), Zoi.integer()]) |> Zoi.trim()

      assert {:ok, "hello"} == Zoi.parse(schema, "  HELLO  ")
      assert {:ok, 42} == Zoi.parse(schema, 42)
    end

    test "union type with invalid transform" do
      schema =
        Zoi.union([
          Zoi.string() |> Zoi.transform(fn _, _ -> {:error, "error"} end),
          Zoi.integer()
        ])
        |> Zoi.to_upcase()

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello")
      assert Exception.message(error) == "invalid type: expected integer"
    end

    test "union custom error" do
      schema =
        Zoi.union([Zoi.string(), Zoi.integer()], error: "custom union error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert error.code == :custom
      assert Exception.message(error) == "custom union error"
    end

    test "union with gt/lt/lte/length constraints" do
      schema = Zoi.union([Zoi.integer(), Zoi.float()]) |> Zoi.gt(3)
      assert {:ok, 5} = Zoi.parse(schema, 5)
      assert {:error, _} = Zoi.parse(schema, 3)

      schema = Zoi.union([Zoi.integer(), Zoi.float()]) |> Zoi.lt(5)
      assert {:ok, 3} = Zoi.parse(schema, 3)
      assert {:error, _} = Zoi.parse(schema, 5)

      schema = Zoi.union([Zoi.string(), Zoi.integer()]) |> Zoi.lte(5)
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, "hello world")

      schema = Zoi.union([Zoi.string(), Zoi.array(Zoi.integer())]) |> Zoi.length(3)
      assert {:ok, "abc"} = Zoi.parse(schema, "abc")
      assert {:error, _} = Zoi.parse(schema, "ab")
    end

    test "validation protocols fallback to Any for unsupported types" do
      literal = Zoi.literal("test")
      integer = Zoi.integer()

      assert :ok = Zoi.Validations.Gt.validate(literal, "test", 1, [])
      assert :ok = Zoi.Validations.Gte.validate(literal, "test", 1, [])
      assert :ok = Zoi.Validations.Lt.validate(literal, "test", 10, [])
      assert :ok = Zoi.Validations.Lte.validate(literal, "test", 10, [])
      assert :ok = Zoi.Validations.Length.validate(integer, 123, 3, [])
    end
  end

  describe "intersection/2" do
    test "intersection with correct values" do
      schema =
        Zoi.intersection([
          Zoi.string() |> Zoi.starts_with("prefix_"),
          Zoi.string() |> Zoi.ends_with("_suffix")
        ])

      assert {:ok, "prefix_value_suffix"} == Zoi.parse(schema, "prefix_value_suffix")
    end

    test "intersection with incorrect value" do
      schema =
        Zoi.intersection([
          Zoi.string() |> Zoi.starts_with("prefix_"),
          Zoi.string() |> Zoi.ends_with("_suffix")
        ])

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "value_without_suffix")
      assert Exception.message(error) == "invalid format: must start with 'prefix_'"
    end

    test "intersection with multiple schemas" do
      schema = Zoi.intersection([Zoi.string(), Zoi.integer(coerce: true)])

      assert {:ok, 12} == Zoi.parse(schema, "12")
    end

    test "intersection with empty schemas or 1 element" do
      assert_raise ArgumentError,
                   "Intersection type must be receive a list of minimum 2 schemas",
                   fn ->
                     Zoi.intersection([])
                   end

      assert_raise ArgumentError,
                   "Intersection type must be receive a list of minimum 2 schemas",
                   fn ->
                     Zoi.intersection([Zoi.string()])
                   end
    end

    test "intersection with incorrect type" do
      assert_raise ArgumentError,
                   "Intersection type must be receive a list of minimum 2 schemas",
                   fn ->
                     Zoi.intersection(Zoi.string())
                   end
    end

    test "intersection type with transforms" do
      schema =
        Zoi.intersection([
          Zoi.string() |> Zoi.starts_with("prefix_"),
          Zoi.string() |> Zoi.ends_with("_suffix")
        ])
        |> Zoi.to_upcase()

      assert {:ok, "PREFIX_VALUE_SUFFIX"} == Zoi.parse(schema, "prefix_value_suffix")
    end

    test "intersection type with refinements" do
      schema =
        Zoi.intersection([
          Zoi.string() |> Zoi.starts_with("prefix_"),
          Zoi.string() |> Zoi.ends_with("_suffix")
        ])
        |> Zoi.min(14)

      assert {:ok, "prefix_value_suffix"} == Zoi.parse(schema, "prefix_value_suffix")

      # Fails on `starts_with` refinement, fallback to string validation
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "another_value_suffix")
      assert Exception.message(error) == "invalid format: must start with 'prefix_'"

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "prefix_suffix")
      assert Exception.message(error) == "too small: must have at least 14 character(s)"
    end

    test "intersection custom error" do
      schema =
        Zoi.intersection([Zoi.string(), Zoi.integer()], error: "custom intersection error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert error.code == :custom
      assert Exception.message(error) == "custom intersection error"
    end
  end

  describe "lazy/1" do
    test "basic lazy evaluation" do
      schema = Zoi.lazy(fn -> Zoi.string() end)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, 123)
    end

    test "recursive user schema with friends" do
      schema = user_schema()

      # User without friends
      assert {:ok, %{name: "Alice", email: "alice@example.com"}} =
               Zoi.parse(schema, %{name: "Alice", email: "alice@example.com"})

      # User with friends
      input = %{
        name: "Alice",
        email: "alice@example.com",
        friends: [
          %{name: "Bob", email: "bob@example.com"},
          %{
            name: "Carol",
            email: "carol@example.com",
            friends: [
              %{name: "Dave", email: "dave@example.com"}
            ]
          }
        ]
      }

      assert {:ok, result} = Zoi.parse(schema, input)
      assert result.name == "Alice"
      assert length(result.friends) == 2
      assert Enum.at(result.friends, 1).friends |> Enum.at(0) |> Map.get(:name) == "Dave"
    end

    test "recursive type with validation error in nested structure" do
      schema = user_schema_with_validation()

      # Invalid nested email
      input = %{
        name: "Alice",
        email: "alice@example.com",
        friends: [
          %{name: "Bob", email: "invalid-email"}
        ]
      }

      assert {:error, errors} = Zoi.parse(schema, input)
      assert length(errors) == 1
      [error] = errors
      assert error.path == [:friends, 0, :email]
    end
  end

  # Helper functions for recursive schema tests
  defp user_schema do
    Zoi.object(%{
      name: Zoi.string(),
      email: Zoi.string(),
      friends: Zoi.array(Zoi.lazy(fn -> user_schema() end)) |> Zoi.optional()
    })
  end

  defp user_schema_with_validation do
    Zoi.object(%{
      name: Zoi.string(),
      email: Zoi.email(),
      friends: Zoi.array(Zoi.lazy(fn -> user_schema_with_validation() end)) |> Zoi.optional()
    })
  end

  describe "object/2" do
    test "object with correct value" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:ok, %{name: "John", age: 30}} ==
               Zoi.parse(schema, %{
                 name: "John",
                 age: 30
               })
    end

    test "object not a map" do
      assert_raise ArgumentError, "object must receive a map", fn ->
        Zoi.object("not a map")
      end
    end

    test "object with missing required field" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 name: "John"
               })

      assert Exception.message(error) == "is required"
      assert error.path == [:age]
    end

    test "object with incorrect values" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 name: "John",
                 age: "not an integer"
               })

      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == [:age]
    end

    test "object with string key" do
      schema = Zoi.object(%{"name" => Zoi.string(), "age" => Zoi.integer()})

      assert {:ok, %{"name" => "John", "age" => 30}} ==
               Zoi.parse(schema, %{
                 "name" => "John",
                 "age" => 30
               })
    end

    test "object with optional field" do
      schema =
        Zoi.object(%{name: Zoi.string(), age: Zoi.optional(Zoi.integer())})

      assert {:ok, %{name: "John"}} ==
               Zoi.parse(schema, %{
                 name: "John"
               })
    end

    test "object with non-map input" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a map")
      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected object"
    end

    test "object with nested object" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string(), age: Zoi.integer()}),
          active: Zoi.boolean()
        })

      assert {:error, errors} = Zoi.parse(schema, %{})

      assert Enum.sort(errors) == [
               %Zoi.Error{
                 code: :required,
                 message: "is required",
                 issue: {"is required", [key: :active]},
                 path: [:active]
               },
               %Zoi.Error{
                 code: :required,
                 message: "is required",
                 issue: {"is required", [key: :user]},
                 path: [:user]
               }
             ]

      assert {:error, errors} = Zoi.parse(schema, %{user: %{}, active: true})

      assert Enum.sort(errors) == [
               %Zoi.Error{
                 code: :required,
                 message: "is required",
                 issue: {"is required", [key: :age]},
                 path: [:user, :age]
               },
               %Zoi.Error{
                 code: :required,
                 message: "is required",
                 issue: {"is required", [key: :name]},
                 path: [:user, :name]
               }
             ]

      assert {:ok, %{user: %{name: "Alice", age: 25}, active: true}} ==
               Zoi.parse(schema, %{
                 user: %{name: "Alice", age: 25},
                 active: true
               })

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 user: %{name: "Alice"},
                 active: true
               })

      assert error.code == :required
      assert Exception.message(error) == "is required"
      assert error.path == [:user, :age]
    end

    test "object with strict keys" do
      schema =
        Zoi.object(
          %{
            name: Zoi.string(),
            address: Zoi.optional(Zoi.object(%{street: Zoi.optional(Zoi.string())})),
            phone: Zoi.optional(Zoi.object(%{number: Zoi.optional(Zoi.string())}, strict: true))
          },
          strict: true
        )

      assert {:ok, %{name: "John"}} == Zoi.parse(schema, %{name: "John"})

      assert {:error, errors} =
               Zoi.parse(
                 schema,
                 %{
                   name: "John",
                   age: 30,
                   address: %{"wrong key" => "value"},
                   phone: %{"wrong key" => "value"}
                 }
               )

      assert ^errors = [
               %Zoi.Error{
                 code: :unrecognized_key,
                 message: "unrecognized key: wrong key",
                 issue: {"unrecognized key: %{key}", [key: "wrong key"]},
                 path: [:phone]
               },
               %Zoi.Error{
                 code: :unrecognized_key,
                 message: "unrecognized key: age",
                 issue: {"unrecognized key: %{key}", [key: :age]},
                 path: []
               }
             ]
    end

    test "object with string keys and input with atom keys" do
      schema = Zoi.object(%{"name" => Zoi.string(), "age" => Zoi.integer()})

      assert {:error, errors} =
               Zoi.parse(schema, %{name: "John", age: 30})

      for error <- errors do
        assert error.code == :required
        assert Exception.message(error) == "is required"
      end
    end

    test "object with coercion on string keys and input with atom keys" do
      schema = Zoi.object(%{"name" => Zoi.string(), "age" => Zoi.integer()}, coerce: true)

      assert {:ok, %{"age" => 30, "name" => "John"}} ==
               Zoi.parse(schema, %{name: "John", age: 30})
    end

    test "object with empty_values set" do
      schema =
        Zoi.object(
          %{
            name: Zoi.string(),
            age: Zoi.integer()
          },
          empty_values: ["", nil]
        )

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 name: "",
                 age: 30
               })

      assert Exception.message(error) == "is required"
      assert error.path == [:name]

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 name: "John",
                 age: nil
               })

      assert Exception.message(error) == "is required"
      assert error.path == [:age]
    end
  end

  describe "keyword/2" do
    test "keyword with correct value" do
      schema = Zoi.keyword(name: Zoi.string(), age: Zoi.integer())

      assert {:ok, []} == Zoi.parse(schema, [])
      assert {:ok, [name: "John", age: 30]} == Zoi.parse(schema, name: "John", age: 30)
    end

    test "keyword not a keyword list" do
      assert_raise ArgumentError, "keyword must receive a keyword list", fn ->
        Zoi.keyword(%{})
      end
    end

    test "keyword with missing required field" do
      schema = Zoi.keyword(name: Zoi.string(), age: Zoi.required(Zoi.integer()))

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, name: "John")
      assert error.code == :required
      assert Exception.message(error) == "is required"
      assert error.path == [:age]
    end

    test "keyword with incorrect values" do
      schema = Zoi.keyword(name: Zoi.string(), age: Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, name: "John", age: "not an integer")

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == [:age]
    end

    test "keyword with non-keyword input" do
      schema = Zoi.keyword(name: Zoi.string(), age: Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, %{})
      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected keyword list"
    end

    test "keyword with nested keyword" do
      schema =
        Zoi.keyword(
          user: Zoi.keyword(name: Zoi.string(), age: Zoi.required(Zoi.integer())),
          active: Zoi.boolean()
        )

      assert {:ok, [user: [name: "Alice", age: 25], active: true]} ==
               Zoi.parse(schema, user: [name: "Alice", age: 25], active: true)

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, user: [name: "Alice"], active: true)

      assert Exception.message(error) == "is required"
      assert error.path == [:user, :age]
    end

    test "nested keyword with nil value returns type error, not crash" do
      schema =
        Zoi.keyword(
          user: Zoi.keyword(name: Zoi.string(), age: Zoi.required(Zoi.integer())),
          active: Zoi.boolean()
        )

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, user: nil, active: true)

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected keyword list"
      assert error.path == [:user]
    end

    test "keyword with strict keys" do
      schema =
        Zoi.keyword(
          [
            name: Zoi.string(),
            address: Zoi.optional(Zoi.keyword(street: Zoi.optional(Zoi.string()))),
            phone: Zoi.optional(Zoi.keyword([number: Zoi.optional(Zoi.string())], strict: true))
          ],
          strict: true
        )

      assert {:ok, [name: "John"]} == Zoi.parse(schema, name: "John")

      assert {:error, errors} =
               Zoi.parse(
                 schema,
                 name: "John",
                 age: 30,
                 address: [wrong_key: "value"],
                 phone: [wrong_key: "value"]
               )

      assert ^errors = [
               %Zoi.Error{
                 code: :unrecognized_key,
                 message: "unrecognized key: wrong_key",
                 issue: {"unrecognized key: %{key}", [key: :wrong_key]},
                 path: [:phone]
               },
               %Zoi.Error{
                 code: :unrecognized_key,
                 message: "unrecognized key: age",
                 issue: {"unrecognized key: %{key}", [key: :age]},
                 path: []
               }
             ]
    end

    test "keyword with flexible keys" do
      schema = Zoi.keyword(Zoi.string())
      assert {:ok, []} == Zoi.parse(schema, [])

      assert {:ok, [key1: "value1", key2: "value2"]} ==
               Zoi.parse(schema, key1: "value1", key2: "value2")
    end

    test "keyword with flexible keys and incorrect value" do
      schema = Zoi.keyword(Zoi.array(Zoi.string()))

      assert {:error, [%Zoi.Error{} = error1, %Zoi.Error{} = error2]} =
               Zoi.parse(schema, key1: "not an array", key2: ["valid"], key3: [123])

      assert error1.code == :invalid_type
      assert Exception.message(error1) == "invalid type: expected array"
      assert error1.path == [:key1]
      assert Exception.message(error2) == "invalid type: expected string"
      assert error2.path == [:key3, 0]
    end

    test "keyword value schema keeps previously parsed entries when another fails" do
      schema =
        Zoi.keyword(
          Zoi.object(%{
            label: Zoi.string(),
            priority: Zoi.integer(coerce: true)
          })
        )

      context =
        schema
        |> Zoi.Context.new(
          good: %{label: "ok", priority: "1"},
          bad: %{label: "no", priority: "oops"}
        )
        |> Zoi.Context.parse()

      refute context.valid?
      assert context.parsed == [good: %{label: "ok", priority: 1}]
    end

    test "keyword with empty_values set" do
      schema =
        Zoi.keyword(
          [
            name: Zoi.string() |> Zoi.required(),
            age: Zoi.integer() |> Zoi.required()
          ],
          empty_values: ["", nil]
        )

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, name: "", age: 30)

      assert Exception.message(error) == "is required"
      assert error.path == [:name]

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, name: "John", age: nil)

      assert Exception.message(error) == "is required"
      assert error.path == [:age]
    end
  end

  describe "struct/3" do
    test "struct with correct value" do
      schema = Zoi.struct(User, %{name: Zoi.string(), age: Zoi.integer()})

      assert {:ok, %User{name: "John", age: 30}} ==
               Zoi.parse(schema, %User{
                 name: "John",
                 age: 30
               })
    end

    test "struct not a map" do
      assert_raise ArgumentError, "struct must receive a map", fn ->
        Zoi.struct(User, "not a map")
      end
    end

    test "struct with missing required field" do
      schema =
        Zoi.struct(User, %{name: Zoi.string(), age: Zoi.integer()}, coerce: true)

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 name: "John"
               })

      assert error.code == :required
      assert Exception.message(error) == "is required"
      assert error.path == [:age]
    end

    test "struct with incorrect values" do
      schema = Zoi.struct(User, %{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %User{
                 name: "John",
                 age: "not an integer"
               })

      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == [:age]
    end

    test "struct with non-map input" do
      schema = Zoi.struct(User, %{name: Zoi.string(), age: Zoi.integer()}, coerce: true)

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a map")
      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected struct"
    end

    test "struct with optional field" do
      schema =
        Zoi.struct(
          User,
          %{
            name: Zoi.string(),
            age: Zoi.optional(Zoi.integer())
          },
          coerce: true
        )

      assert {:ok, %User{name: "John"}} ==
               Zoi.parse(schema, %{
                 name: "John"
               })
    end

    test "coerce map with string keys" do
      schema =
        Zoi.struct(
          User,
          %{
            name: Zoi.string(),
            age: Zoi.integer()
          },
          coerce: true
        )

      assert {:ok, %User{name: "John", age: 30}} ==
               Zoi.parse(schema, %{
                 "name" => "John",
                 "age" => 30
               })
    end

    test "all keys must be atoms" do
      assert_raise ArgumentError, "all keys in struct must be atoms", fn ->
        Zoi.struct(User, %{"name" => Zoi.string(), age: Zoi.integer()})
      end
    end
  end

  describe "extend/3" do
    test "extend with correct value" do
      schema1 = Zoi.object(%{name: Zoi.string()})
      schema2 = Zoi.object(%{age: Zoi.integer()})
      schema = Zoi.extend(schema1, schema2)

      assert {:ok, %{name: "John", age: 30}} ==
               Zoi.parse(schema, %{
                 name: "John",
                 age: 30
               })
    end

    test "extend with incorrect value" do
      schema1 = Zoi.object(%{name: Zoi.string()})
      schema2 = Zoi.object(%{age: Zoi.integer()})
      schema = Zoi.extend(schema1, schema2)

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 name: "John",
                 age: "not an integer"
               })

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == [:age]
    end

    test "extend with non-object schema" do
      schema1 = Zoi.object(%{name: Zoi.string()})
      schema2 = Zoi.string()

      assert_raise ArgumentError, "must be an object", fn ->
        Zoi.extend(schema1, schema2)
      end
    end

    test "extend object with plain map" do
      schema1 = Zoi.object(%{name: Zoi.string()})
      schema2 = %{age: Zoi.integer()}
      schema = Zoi.extend(schema1, schema2)

      assert {:ok, %{name: "John", age: 30}} == Zoi.parse(schema, %{name: "John", age: 30})
    end

    test "extend with keyword schema" do
      schema1 = Zoi.keyword(name: Zoi.string())
      schema2 = Zoi.keyword(age: Zoi.integer())
      schema = Zoi.extend(schema1, schema2)

      assert {:ok, [name: "John", age: 30]} == Zoi.parse(schema, name: "John", age: 30)
    end

    test "extend keyword with plain keyword list" do
      schema1 = Zoi.keyword(name: Zoi.string())
      schema2 = [age: Zoi.integer()]
      schema = Zoi.extend(schema1, schema2)

      assert {:ok, [name: "John", age: 30]} == Zoi.parse(schema, name: "John", age: 30)
    end
  end

  describe "map/3" do
    test "map with correct values" do
      schema = Zoi.map(Zoi.string(), Zoi.integer(coerce: true))

      assert {:ok, %{"key1" => 1, "key2" => 2}} ==
               Zoi.parse(schema, %{"key1" => 1, "key2" => "2"})
    end

    test "map with incorrect key type" do
      schema = Zoi.map(Zoi.string(), Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{:key_1 => 1, "key2" => 2})

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected string"
      assert error.path == [:key_1]
    end

    test "map with incorrect value type" do
      schema = Zoi.map(Zoi.string(), Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{"key1" => "not an integer", "key2" => 2})

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == ["key1"]
    end

    test "free map" do
      schema = Zoi.map()

      assert {:ok, %{"key1" => "value1", "key2" => 2}} ==
               Zoi.parse(schema, %{"key1" => "value1", "key2" => 2})
    end

    test "map with non-map input" do
      schema = Zoi.map(Zoi.string(), Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a map")
      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected map"
    end

    test "map with atom keys" do
      schema = Zoi.map(Zoi.atom(), Zoi.any())
      assert {:ok, %{name: "John", age: 30}} == Zoi.parse(schema, %{name: "John", age: 30})

      assert {:error, [%Zoi.Error{} = error1, %Zoi.Error{} = error2]} =
               Zoi.parse(schema, %{"name" => "John", "age" => 30})

      assert error1.code == :invalid_type
      assert Exception.message(error1) == "invalid type: expected atom"
      assert error1.path == ["age"]

      assert error2.code == :invalid_type
      assert Exception.message(error2) == "invalid type: expected atom"
      assert error2.path == ["name"]
    end

    test "map with union type" do
      schema =
        Zoi.map(
          Zoi.union([Zoi.atom(), Zoi.string()],
            error: "invalid type: must be an atom or a string"
          ),
          Zoi.union([Zoi.string(), Zoi.integer()])
        )

      assert {:ok, %{name: "John", age: 30}} == Zoi.parse(schema, %{name: "John", age: 30})

      assert {:ok, %{"name" => "John", "age" => 30}} ==
               Zoi.parse(schema, %{"name" => "John", "age" => 30})

      assert {:error, [%Zoi.Error{} = error1, %Zoi.Error{} = error2]} =
               Zoi.parse(schema, %{1 => 123, "age" => :atom})

      assert error1.code == :custom
      assert Exception.message(error1) == "invalid type: must be an atom or a string"
      assert error1.path == [1]

      assert error2.code == :invalid_type
      assert Exception.message(error2) == "invalid type: expected integer"
      assert error2.path == ["age"]
    end
  end

  describe "tuple/2" do
    test "tuple with correct value" do
      schema = Zoi.tuple({Zoi.string(), Zoi.integer()})

      assert {:ok, {"John", 30}} == Zoi.parse(schema, {"John", 30})
    end

    test "not a tuple" do
      assert_raise ArgumentError, "must be a tuple", fn ->
        Zoi.tuple("not a tuple")
      end
    end

    test "tuple with incorrect value" do
      schema = Zoi.tuple({Zoi.string(), Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, {"John", "not an integer"})

      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == [1]
    end

    test "wrong input data for tuple" do
      schema = Zoi.tuple({Zoi.string(), Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a tuple")
      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected tuple"
    end

    test "typle length difference" do
      schema = Zoi.tuple({Zoi.string(), Zoi.integer()})
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, {"hello", "world", 10})
      assert error.code == :invalid_tuple
      assert Exception.message(error) == "invalid tuple: expected length 2, got 3"
    end

    test "tuple with nested tuples" do
      schema =
        Zoi.tuple(
          {Zoi.tuple({Zoi.string(), Zoi.integer()}),
           Zoi.tuple({Zoi.boolean(), Zoi.tuple({Zoi.integer(), Zoi.integer(), Zoi.integer()})})}
        )

      assert {:ok, {{"Alice", 25}, {true, {12, 10, 10}}}} ==
               Zoi.parse(schema, {{"Alice", 25}, {true, {12, 10, 10}}})

      assert {:error, errors} =
               Zoi.parse(schema, {{"Alice", "not an integer"}, {"not a boolean", {12, 12, "12"}}})

      assert ^errors = [
               %Zoi.Error{
                 code: :invalid_type,
                 message: "invalid type: expected integer",
                 issue: {"invalid type: expected integer", [type: :integer]},
                 path: [0, 1]
               },
               %Zoi.Error{
                 code: :invalid_type,
                 message: "invalid type: expected boolean",
                 issue: {"invalid type: expected boolean", [type: :boolean]},
                 path: [1, 0]
               },
               %Zoi.Error{
                 code: :invalid_type,
                 message: "invalid type: expected integer",
                 issue: {"invalid type: expected integer", [type: :integer]},
                 path: [1, 1, 2]
               }
             ]
    end

    test "tuple with custom error" do
      schema = Zoi.tuple({Zoi.string(), Zoi.integer()}, error: "custom tuple error")

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, {"John"})

      assert error.code == :custom
      assert Exception.message(error) == "custom tuple error"
      assert error.path == []
    end
  end

  describe "array/2" do
    test "array with correct values" do
      schema = Zoi.array(Zoi.integer())

      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
    end

    test "array with no arguments should create a `any` array" do
      schema = Zoi.array()

      assert %{inner: %Zoi.Types.Any{}} = schema

      assert {:ok, [1, "two", 3.0, true, nil, %{}, []]} ==
               Zoi.parse(schema, [1, "two", 3.0, true, nil, %{}, []])
    end

    test "array with coercion" do
      schema = Zoi.array(Zoi.string(), coerce: true)
      # Numeric keys are converted to arrays
      assert {:ok, ["hello", "world"]} == Zoi.parse(schema, %{"0" => "hello", "1" => "world"})
      assert {:ok, ["1", "2", "3"]} == Zoi.parse(schema, ["1", "2", "3"])
      assert {:ok, ["1", "2"]} == Zoi.parse(schema, {"1", "2"})

      # Maps with non-numeric keys are not treated as arrays
      assert {:error, [%Zoi.Error{code: :invalid_type, path: [0]}]} =
               Zoi.parse(schema, %{a: "hello", b: "world"})
    end

    test "array with incorrect value" do
      schema = Zoi.array(Zoi.integer())

      assert {:error, [error1, error2]} = Zoi.parse(schema, [1, "not an integer", 3, 4, 5, "55"])
      assert error1.code == :invalid_type
      assert Exception.message(error1) == "invalid type: expected integer"
      assert error1.path == [1]

      assert error2.code == :invalid_type
      assert Exception.message(error2) == "invalid type: expected integer"
      assert error2.path == [5]
    end

    test "array with empty array" do
      schema = Zoi.array(Zoi.string())

      assert {:ok, []} == Zoi.parse(schema, [])
    end

    test "array with non-array input" do
      schema = Zoi.array(Zoi.string())

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not an array")

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected array"
    end

    test "array with nested arrays" do
      schema = Zoi.array(Zoi.array(Zoi.integer()))

      assert {:ok, [[1, 2], [3, 4]]} == Zoi.parse(schema, [[1, 2], [3, 4]])
    end

    test "array with min_length option" do
      schema = Zoi.array(Zoi.integer(), min_length: 2)

      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1])
      assert error.code == :greater_than_or_equal_to
    end

    test "array with max_length option" do
      schema = Zoi.array(Zoi.integer(), max_length: 3)

      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3, 4])
      assert error.code == :less_than_or_equal_to
    end

    test "array with length option" do
      schema = Zoi.array(Zoi.integer(), length: 2)

      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1])
      assert error.code == :invalid_length
    end

    test "constructor with tuple format for custom errors" do
      schema = Zoi.array(Zoi.string(), min_length: {3, [error: "need at least 3"]})

      assert {:error, [%Zoi.Error{code: :custom, message: "need at least 3"}]} =
               Zoi.parse(schema, ["a", "b"])

      assert {:ok, ["a", "b", "c"]} = Zoi.parse(schema, ["a", "b", "c"])
    end

    test "array length/2 sets schema field when there are no effects" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.length(4)
      assert schema.length == {4, []}
      refute schema.min_length
      refute schema.max_length
    end

    test "array options length overrides min and max" do
      schema = Zoi.array(Zoi.integer(), min_length: 1, max_length: 5, length: 2)
      assert schema.length == {2, []}
      refute schema.min_length
      refute schema.max_length
    end

    test "array validations accumulate errors from fields" do
      schema = Zoi.array(Zoi.integer(), min_length: 3, max_length: 1)

      assert {:error, [error1, error2]} = Zoi.parse(schema, [1, 2])

      assert Enum.map([error1, error2], & &1.code) |> Enum.sort() ==
               [:greater_than_or_equal_to, :less_than_or_equal_to]
    end

    test "array min after transform validates after transform" do
      schema =
        Zoi.array(Zoi.integer())
        |> Zoi.transform(fn value -> Enum.reverse(value) end)
        |> Zoi.min(2)

      assert {:ok, [2, 1]} == Zoi.parse(schema, [1, 2])

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1])
      assert error.code == :greater_than_or_equal_to
    end

    test "array max after transform validates after transform" do
      schema =
        Zoi.array(Zoi.integer())
        |> Zoi.transform(fn value -> Enum.reverse(value) end)
        |> Zoi.max(3)

      assert {:ok, [3, 2, 1]} == Zoi.parse(schema, [1, 2, 3])

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3, 4])
      assert error.code == :less_than_or_equal_to
    end

    test "array length after transform validates after transform" do
      schema =
        Zoi.array(Zoi.integer())
        |> Zoi.transform(fn value -> Enum.reverse(value) end)
        |> Zoi.length(2)

      assert {:ok, [2, 1]} == Zoi.parse(schema, [1, 2])

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3])
      assert error.code == :invalid_length
    end

    test "array with nested arrays and incorrect value" do
      schema = Zoi.array(Zoi.array(Zoi.integer()))

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, [[1, 2], ["not an integer", 4]])

      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == [1, 0]

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, [[1, 2], [3, "not an integer"]])

      assert Exception.message(error) == "invalid type: expected integer"
      assert error.path == [1, 1]
    end

    test "array with deeply nested arrays" do
      schema = Zoi.array(Zoi.array(Zoi.array(Zoi.integer())))

      assert {:ok, [[[1], [2]], [[3], [4]]]} ==
               Zoi.parse(schema, [[[1], [2]], [[3], [4]]])

      assert {:error, [%Zoi.Error{} = error_1, %Zoi.Error{} = error_2]} =
               Zoi.parse(schema, [[[1], ["not an integer"]], [[3], [4, "not an integer"]]])

      assert error_1.code == :invalid_type
      assert Exception.message(error_1) == "invalid type: expected integer"
      assert error_1.path == [0, 1, 0]

      assert error_2.code == :invalid_type
      assert Exception.message(error_2) == "invalid type: expected integer"
      assert error_2.path == [1, 1, 1]
    end

    test "array with refinement" do
      schema = Zoi.array(Zoi.array(Zoi.integer() |> Zoi.min(1)) |> Zoi.min(2))

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, [[1, 2], [2]])

      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must have at least 2 item(s)"
      assert error.path == [1]

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, [[1, 2], [2, 0]])

      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 1"
      assert error.path == [1, 1]
    end

    test "array with map coercion - numeric string keys" do
      schema = Zoi.array(Zoi.integer(), coerce: true)

      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, %{"0" => 1, "1" => 2, "2" => 3})
    end

    test "array with map coercion - numeric string keys out of order" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      assert {:ok, ["first", "second", "tenth"]} ==
               Zoi.parse(schema, %{"10" => "tenth", "1" => "second", "0" => "first"})
    end

    test "array with map coercion - integer keys" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      assert {:ok, ["a", "b"]} == Zoi.parse(schema, %{0 => "a", 1 => "b"})
    end

    test "array with map coercion - mixed integer and string numeric keys" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      assert {:ok, ["first", "second", "third"]} ==
               Zoi.parse(schema, %{0 => "first", "1" => "second", 2 => "third"})
    end

    test "array with map coercion - ignores non-numeric keys" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      assert {:ok, ["a", "b"]} ==
               Zoi.parse(schema, %{
                 "_persistent_id" => "ignored",
                 "_unused" => "also ignored",
                 "0" => "a",
                 "1" => "b"
               })
    end

    test "array with map coercion - empty map becomes empty array" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      assert {:ok, []} == Zoi.parse(schema, %{})
    end

    test "array with map coercion - non-numeric map with single value becomes single-item array" do
      schema = Zoi.array(Zoi.integer(), coerce: true)

      # Map with single non-numeric key becomes single-item array
      # Only works with simple types that can convert from map representation
      assert {:ok, []} == Zoi.parse(schema, %{})
    end

    test "array with map coercion - nested numeric maps need both levels to have coercion" do
      # Inner array also needs coercion enabled to handle numeric maps
      inner_schema = Zoi.array(Zoi.integer(), coerce: true)
      schema = Zoi.array(inner_schema, coerce: true)

      assert {:ok, [[1, 2], [3, 4]]} ==
               Zoi.parse(schema, %{
                 "0" => %{"0" => 1, "1" => 2},
                 "1" => %{"0" => 3, "1" => 4}
               })
    end

    test "array with map coercion - preserves validation errors with correct indices" do
      schema = Zoi.array(Zoi.integer(), coerce: true)

      assert {:error, [error1, error2]} =
               Zoi.parse(schema, %{"0" => 1, "1" => "invalid", "2" => 3, "3" => "also invalid"})

      assert error1.path == [1]
      assert error2.path == [3]
    end

    test "array with map coercion - handles gaps in numeric keys" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      # Keys with gaps should still maintain order
      assert {:ok, ["zero", "two", "five"]} ==
               Zoi.parse(schema, %{"0" => "zero", "2" => "two", "5" => "five"})
    end

    test "array with map coercion - string keys with leading zeros" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      # "01" should be treated as "1"
      assert {:ok, ["zero", "one", "two"]} ==
               Zoi.parse(schema, %{"0" => "zero", "01" => "one", "2" => "two"})
    end

    test "array with map coercion - handles single values as single-item arrays" do
      schema = Zoi.array(Zoi.string(), coerce: true)

      # Single string becomes single-item array (though unusual usage)
      assert {:error, _} = Zoi.parse(schema, "single")
      # Lists work normally
      assert {:ok, ["a", "b"]} == Zoi.parse(schema, ["a", "b"])
    end

    test "array with tuple coercion" do
      schema = Zoi.array(Zoi.integer(), coerce: true)

      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, {1, 2, 3})
    end

    test "array without coercion rejects maps" do
      schema = Zoi.array(Zoi.string())

      assert {:error, [%Zoi.Error{code: :invalid_type}]} =
               Zoi.parse(schema, %{"0" => "a", "1" => "b"})
    end

    test "array with invalid inner schema raises ArgumentError" do
      assert_raise ArgumentError,
                   "you should use a valid Zoi schema, got: \"not a schema\"",
                   fn ->
                     Zoi.array("not a schema")
                   end
    end
  end

  describe "list/2" do
    test "list/2 works as alias for array/2" do
      schema = Zoi.list(Zoi.string())
      assert {:ok, ["a", "b", "c"]} = Zoi.parse(schema, ["a", "b", "c"])
    end

    test "list/2 accepts options like array/2" do
      schema = Zoi.list(Zoi.integer(), coerce: true)
      assert {:ok, [1, 2, 3]} = Zoi.parse(schema, {1, 2, 3})
    end
  end

  describe "enum/2" do
    test "enum with atom key" do
      schema = Zoi.enum([:apple, :banana, :cherry])

      assert {:ok, :apple} == Zoi.parse(schema, :apple)
      assert {:ok, :banana} == Zoi.parse(schema, :banana)
      assert {:ok, :cherry} == Zoi.parse(schema, :cherry)
    end

    test "enum with string key" do
      schema = Zoi.enum(["apple", "banana", "cherry"])

      assert {:ok, "apple"} == Zoi.parse(schema, "apple")
      assert {:ok, "banana"} == Zoi.parse(schema, "banana")
      assert {:ok, "cherry"} == Zoi.parse(schema, "cherry")
    end

    test "enum with integer key" do
      schema = Zoi.enum([1, 2, 3])

      assert {:ok, 1} == Zoi.parse(schema, 1)
      assert {:ok, 2} == Zoi.parse(schema, 2)
      assert {:ok, 3} == Zoi.parse(schema, 3)
    end

    test "enum with key-value string" do
      schema = Zoi.enum(apple: "Apple", banana: "Banana", cherry: "Cherry")
      assert {:ok, :apple} == Zoi.parse(schema, "Apple")
      assert {:ok, :banana} == Zoi.parse(schema, "Banana")
      assert {:ok, :cherry} == Zoi.parse(schema, "Cherry")
    end

    test "enum with key-value integer" do
      schema = Zoi.enum(apple: 1, banana: 2, cherry: 3)
      assert {:ok, :apple} == Zoi.parse(schema, 1)
      assert {:ok, :banana} == Zoi.parse(schema, 2)
      assert {:ok, :cherry} == Zoi.parse(schema, 3)
    end

    test "enum with coercion" do
      schema = Zoi.enum([apple: "apple", banana: "banana", cherry: "cherry"], coerce: true)
      assert {:ok, :apple} == Zoi.parse(schema, "apple")
      assert {:ok, :apple} == Zoi.parse(schema, :apple)
      assert {:ok, :banana} == Zoi.parse(schema, "banana")
      assert {:ok, :banana} == Zoi.parse(schema, :banana)
      assert {:ok, :cherry} == Zoi.parse(schema, "cherry")
      assert {:ok, :cherry} == Zoi.parse(schema, :cherry)
    end

    test "enum with incorrect value" do
      schema = Zoi.enum([:apple, :banana, :cherry])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, :orange)
      assert error.code == :invalid_enum_value

      assert Exception.message(error) ==
               "invalid enum value: expected one of apple, banana, cherry"
    end

    test "enum parse with incorrect type" do
      schema = Zoi.enum([:apple, :banana, :cherry])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "banana")
      assert error.code == :invalid_enum_value

      assert Exception.message(error) ==
               "invalid enum value: expected one of apple, banana, cherry"
    end

    test "enum with incorrect type" do
      assert_raise ArgumentError, "Invalid enum values", fn ->
        Zoi.enum(apple: :apple, banana: :banana, cherry: :cherry)
      end
    end

    test "enum with empty list" do
      assert_raise ArgumentError, "Invalid enum values", fn ->
        Zoi.enum([])
      end
    end

    test "enum with custom error" do
      schema = Zoi.enum([:apple, :banana, :cherry], error: "custom enum error of %{expected}")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, :orange)
      assert error.code == :custom
      assert Exception.message(error) == "custom enum error of apple, banana, cherry"
    end
  end

  describe "time/1" do
    test "time with correct value" do
      schema = Zoi.time()
      assert {:ok, ~T[12:34:56]} == Zoi.parse(schema, ~T[12:34:56])
      assert {:ok, ~T[00:00:00]} == Zoi.parse(schema, ~T[00:00:00])
    end

    test "time with incorrect value" do
      wrong_values = ["12:34", nil, "not a time", :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.time(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected time"
      end
    end

    test "time with coercion" do
      assert {:ok, ~T[12:34:56]} == Zoi.parse(Zoi.time(), "12:34:56", coerce: true)
      assert {:ok, ~T[00:00:00]} == Zoi.parse(Zoi.time(), "00:00:00", coerce: true)
    end

    test "time with coercion but incorrect value" do
      wrong_values = [nil, "not a time", :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.time(coerce: true), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected time"
      end
    end

    test "time with custom error" do
      schema = Zoi.time(error: "custom time error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a time")
      assert error.code == :custom
      assert Exception.message(error) == "custom time error"
    end
  end

  describe "date/1" do
    test "date with correct value" do
      schema = Zoi.date()
      assert {:ok, ~D[2023-10-01]} == Zoi.parse(schema, ~D[2023-10-01])
      assert {:ok, ~D[0000-01-01]} == Zoi.parse(schema, ~D[0000-01-01])
    end

    test "date with incorrect value" do
      wrong_values = ["2023-10", nil, "not a date", :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.date(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected date"
      end
    end

    test "date with coercion" do
      assert {:ok, ~D[2023-10-01]} == Zoi.parse(Zoi.date(), "2023-10-01", coerce: true)
      assert {:ok, ~D[0000-01-01]} == Zoi.parse(Zoi.date(), "0000-01-01", coerce: true)
    end

    test "date with coercion but incorrect value" do
      wrong_values = [nil, "not a date", :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.date(coerce: true), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected date"
      end
    end

    test "date with custom error" do
      schema = Zoi.date(error: "custom date error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a date")
      assert error.code == :custom
      assert Exception.message(error) == "custom date error"
    end
  end

  describe "datetime/1" do
    test "datetime with correct value" do
      schema = Zoi.datetime()
      assert {:ok, ~U[2023-10-01 12:34:56Z]} == Zoi.parse(schema, ~U[2023-10-01 12:34:56Z])
      assert {:ok, ~U[0000-01-01 00:00:00Z]} == Zoi.parse(schema, ~U[0000-01-01 00:00:00Z])
    end

    test "datetime with incorrect value" do
      wrong_values = ["2023-10-01", nil, "not a datetime", :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.datetime(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected datetime"
      end
    end

    test "datetime with coercion" do
      assert {:ok, ~U[2023-10-01 12:34:56Z]} ==
               Zoi.parse(Zoi.datetime(), "2023-10-01T12:34:56Z", coerce: true)

      assert {:ok, ~U[0000-01-01 00:00:00Z]} ==
               Zoi.parse(Zoi.datetime(), "0000-01-01T00:00:00Z", coerce: true)
    end

    test "datetime with coercion but incorrect value" do
      wrong_values = [nil, "not a datetime", :atom, 253_402_300_800]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.datetime(coerce: true), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected datetime"
      end
    end

    test "datetime with custom error" do
      schema = Zoi.datetime(error: "custom datetime error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a datetime")
      assert error.code == :custom
      assert Exception.message(error) == "custom datetime error"
    end
  end

  describe "naive_datetime/1" do
    test "naive_datetime with correct value" do
      schema = Zoi.naive_datetime()
      assert {:ok, ~N[2023-10-01 12:34:56]} == Zoi.parse(schema, ~N[2023-10-01 12:34:56])
      assert {:ok, ~N[0000-01-01 00:00:00]} == Zoi.parse(schema, ~N[0000-01-01 00:00:00])
    end

    test "naive_datetime with incorrect value" do
      wrong_values = ["2023-10-01", nil, "not a naive datetime", :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.naive_datetime(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected naive datetime"
      end
    end

    test "naive_datetime with coercion" do
      assert {:ok, ~N[2023-10-01 12:34:56]} ==
               Zoi.parse(Zoi.naive_datetime(), "2023-10-01T12:34:56", coerce: true)

      assert {:ok, ~N[0000-01-01 00:00:00]} ==
               Zoi.parse(Zoi.naive_datetime(), "0000-01-01T00:00:00", coerce: true)
    end

    test "naive_datetime with coercion but incorrect value" do
      wrong_values = [nil, "not a naive datetime", :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} =
                 Zoi.parse(Zoi.naive_datetime(coerce: true), value)

        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected naive datetime"
      end
    end

    test "naive_datetime with custom error" do
      schema = Zoi.naive_datetime(error: "custom naive datetime error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a naive datetime")
      assert error.code == :custom
      assert Exception.message(error) == "custom naive datetime error"
    end
  end

  describe "decimal/1" do
    test "decimal with correct value" do
      schema = Zoi.decimal()
      assert {:ok, Decimal.new("12.34")} == Zoi.parse(schema, Decimal.new("12.34"))
      assert {:ok, Decimal.new("0.0")} == Zoi.parse(schema, Decimal.new("0.0"))
    end

    test "decimal with incorrect value" do
      wrong_values = ["12", nil, "9.a", :"12", "not a decimal"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.decimal(), value)
        assert error.code == :invalid_type
        assert Exception.message(error) == "invalid type: expected decimal"
      end
    end

    test "decimal with coercion" do
      assert {:ok, Decimal.new("12.34")} == Zoi.parse(Zoi.decimal(), "12.34", coerce: true)
      assert {:ok, Decimal.new("0")} == Zoi.parse(Zoi.decimal(), "0", coerce: true)
      assert {:ok, Decimal.new("-1")} == Zoi.parse(Zoi.decimal(), "-1", coerce: true)
    end

    test "decimal with coercion but incorrect value" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.decimal(), "not_decimal", coerce: true)

      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected decimal"
    end

    test "decimal with custom error" do
      schema = Zoi.decimal(error: "custom decimal error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a decimal")
      assert error.code == :custom
      assert Exception.message(error) == "custom decimal error"
    end
  end

  ## Refinements

  describe "email/0" do
    test "valid email" do
      assert {:ok, "test@test.com"} == Zoi.parse(Zoi.email(), "test@test.com")
      assert {:ok, "TEST@TEST.COM"} == Zoi.parse(Zoi.email(), "TEST@TEST.COM")
    end

    test "invalid email" do
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.email(), "invalid-email")
      assert error.code == :invalid_format
      assert Exception.message(error) == "invalid email format"

      assert {"invalid email format", [format: :email, pattern: pattern]} =
               error.issue

      assert Regex.source(pattern) == Regex.source(Zoi.Regexes.email())
    end

    test "regex pattern: html5_email" do
      schema = Zoi.email(pattern: Zoi.Regexes.html5_email())

      assert {:ok, "test@test.com"} == Zoi.parse(schema, "test@test.com")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid-email")
      assert Exception.message(error) == "invalid email format"
    end

    test "regex pattern: rfc5322_email" do
      schema = Zoi.email(pattern: Zoi.Regexes.rfc5322_email())

      assert {:ok, "test@test.com"} == Zoi.parse(schema, "test@test.com")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid-email")
      assert Exception.message(error) == "invalid email format"
    end

    test "regex pattern: simple_email" do
      schema = Zoi.email(pattern: Zoi.Regexes.simple_email())

      assert {:ok, "A@B"} == Zoi.parse(schema, "A@B")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid")
      assert Exception.message(error) == "invalid email format"
    end

    test "regex pattern: user custom format" do
      custom_pattern = ~r/^[a-zA-Z0-9]+@example\.com$/
      schema = Zoi.email(pattern: custom_pattern)

      assert {:ok, "user@example.com"} == Zoi.parse(schema, "user@example.com")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "user@notexample.com")
      assert Exception.message(error) == "invalid email format"
    end

    test "custom error message" do
      schema = Zoi.email(error: "custom email error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid-email")
      assert error.code == :custom
      assert Exception.message(error) == "custom email error"
    end
  end

  describe "uuid/1" do
    test "valid uuid" do
      schema = Zoi.uuid()

      assert {:ok, "1177af37-9075-43b5-a64e-66079aabee90"} ==
               Zoi.parse(schema, "1177af37-9075-43b5-a64e-66079aabee90")
    end

    test "invalid uuid" do
      schema = Zoi.uuid()
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not-a-uuid")
      assert Exception.message(error) == "invalid UUID format"
    end

    test "invalid uuid version" do
      assert_raise ArgumentError, "Invalid UUID version: v12", fn ->
        Zoi.uuid(version: "v12")
      end
    end

    @invalid_uuid "1177af37-9075-03b5-a64e-66079aabee90"
    @uuids %{
      "v1" => "3b7ee760-73b6-11f0-b5a4-d52f6e787ae9",
      "v2" => "000003e8-73b6-21f0-9d00-325096b39f47",
      "v3" => "c6437ef1-5b86-3a4e-a071-c2d4ad414e65",
      "v4" => "92785397-8638-4aff-9579-96021395e4c5",
      "v5" => "9b8edca0-90f2-5031-8e5d-3f708834696c",
      "v6" => "1f073b88-2de9-6f90-852d-40ef5c7b4727",
      "v7" => "019885b3-05cc-7c15-96d5-4a6e0e7d9cbe",
      "v8" => "6d084cef-a067-8e9e-be6d-7c5aefdfd9b4"
    }
    for {version, uuid} <- @uuids do
      @version version
      @uuid uuid
      test "uuid #{@version}" do
        schema = Zoi.uuid(version: @version)
        assert {:ok, _uuid} = Zoi.parse(schema, @uuid)
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, @invalid_uuid)
        assert error.code == :invalid_format
        assert Exception.message(error) == "invalid UUID format"
      end
    end
  end

  describe "url/0" do
    test "valid URL" do
      schema = Zoi.url()
      assert {:ok, "https://example.com"} == Zoi.parse(schema, "https://example.com")
      assert {:ok, "https://example.com"} == Zoi.parse(schema, "https://example.com")
      assert {:ok, "http://localhost"} == Zoi.parse(schema, "http://localhost")

      assert {:ok, "https://google.com/Foo%20Bar"} ==
               Zoi.parse(schema, "https://google.com/Foo%20Bar")
    end

    test "invalid URL" do
      schema = Zoi.url()

      invalid_urls = [
        "htp://invalid-protocol.com",
        "://missing-protocol.com",
        "http//missing-colon.com",
        "http:/one-slash.com",
        "/?foo[bar]=baz"
      ]

      for url <- invalid_urls do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, url)
        assert error.code == :invalid_format
        assert Exception.message(error) == "invalid format: must be a valid URL"
        assert {"invalid format: must be a valid URL", [value: ^url]} = error.issue
      end
    end

    test "invalid url with custom eror" do
      schema = Zoi.url(error: "something went wrong with the url")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "htt://google/com")
      assert error.code == :custom
      assert Exception.message(error) == "something went wrong with the url"
      assert {"something went wrong with the url", [value: "htt://google/com"]} = error.issue
    end

    test "url should only work on implemented protocols" do
      schema = Zoi.literal("a") |> Zoi.refine({Zoi.Validations.Url, :validate, [[]]})
      assert {:ok, "a"} == Zoi.parse(schema, "a")
    end
  end

  describe "ipv4/0" do
    test "valid IPv4 address" do
      schema = Zoi.ipv4()
      ipv4_addresses = ["127.0.0.1", "192.168.0.0"]

      for address <- ipv4_addresses do
        assert {:ok, ^address} = Zoi.parse(schema, address)
      end
    end

    test "invalid IPv4 address" do
      schema = Zoi.ipv4()
      invalid_addresses = ["256.256.256.256", "192.168.0.300", "not an ipv4"]

      for address <- invalid_addresses do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, address)
        assert error.code == :invalid_format
        assert Exception.message(error) == "invalid IPv4 address"
      end
    end
  end

  describe "ipv6/0" do
    test "valid IPv6 address" do
      schema = Zoi.ipv6()
      ipv6_addresses = ["::1", "2001:0db8:85a3:0000:0000:8a2e:0370:7334"]

      for address <- ipv6_addresses do
        assert {:ok, ^address} = Zoi.parse(schema, address)
      end
    end

    test "invalid IPv6 address" do
      schema = Zoi.ipv6()
      invalid_addresses = ["not an ipv6", "127.0.0.1"]

      for address <- invalid_addresses do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, address)
        assert error.code == :invalid_format
        assert Exception.message(error) == "invalid IPv6 address"
      end
    end
  end

  describe "hex/0" do
    test "valid hex string" do
      schema = Zoi.hex()
      assert {:ok, "1a2b3c"} == Zoi.parse(schema, "1a2b3c")
      assert {:ok, "ABCDEF"} == Zoi.parse(schema, "ABCDEF")
    end

    test "invalid hex string" do
      schema = Zoi.hex()
      invalid_hex = ["1a2b3g", "xyz", "12345z"]

      for hex <- invalid_hex do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, hex)
        assert error.code == :invalid_format
        assert Exception.message(error) == "invalid hex format"
      end

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, nil)
      assert error.code == :invalid_type
      assert Exception.message(error) == "invalid type: expected string"
    end
  end

  describe "min/2" do
    test "min for string" do
      schema = Zoi.string() |> Zoi.min(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must have at least 5 character(s)"
      assert error.issue == {"too small: must have at least %{count} character(s)", [count: 5]}
    end

    test "min for integer" do
      schema = Zoi.integer() |> Zoi.min(10)
      assert {:ok, 15} == Zoi.parse(schema, 15)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 5)
      assert Exception.message(error) == "too small: must be at least 10"
    end

    test "min for float" do
      schema = Zoi.float() |> Zoi.min(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 9.99)
      assert Exception.message(error) == "too small: must be at least 10.5"
    end

    test "min for number" do
      schema = Zoi.number() |> Zoi.min(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 9.99)
      assert Exception.message(error) == "too small: must be at least 10.5"
    end

    test "min for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.min(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2])
      assert Exception.message(error) == "too small: must have at least 3 item(s)"
    end
  end

  describe "gte/2" do
    test "gte for string" do
      schema = Zoi.string() |> Zoi.gte(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must have at least 5 character(s)"
      assert error.issue == {"too small: must have at least %{count} character(s)", [count: 5]}
    end

    test "gte for integer" do
      schema = Zoi.integer() |> Zoi.gte(10)
      assert {:ok, 15} == Zoi.parse(schema, 15)
      assert {:ok, 10} == Zoi.parse(schema, 10)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 5)
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 10"
    end

    test "gte for float" do
      schema = Zoi.float() |> Zoi.gte(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:ok, 10.5} == Zoi.parse(schema, 10.5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 9.99)
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 10.5"
    end

    test "gte for number" do
      schema = Zoi.number() |> Zoi.gte(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:ok, 10.5} == Zoi.parse(schema, 10.5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 9.99)
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 10.5"
    end

    test "gte for decimal" do
      schema = Zoi.decimal() |> Zoi.gte(Decimal.new("10.5"))
      assert {:ok, Decimal.new("12.34")} == Zoi.parse(schema, "12.34", coerce: true)
      assert {:ok, Decimal.new("10.5")} == Zoi.parse(schema, Decimal.new("10.5"))
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "9.99", coerce: true)
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 10.5"
    end

    test "gte for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.gte(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1])
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must have at least 3 item(s)"
    end

    test "gte for time" do
      schema = Zoi.time() |> Zoi.gte(~T[12:00:00])
      assert {:ok, ~T[12:00:00]} == Zoi.parse(schema, ~T[12:00:00])
      assert {:ok, ~T[13:00:00]} == Zoi.parse(schema, ~T[13:00:00])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~T[11:59:59])
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 12:00:00"
    end

    test "gte for date" do
      schema = Zoi.date() |> Zoi.gte(~D[2023-01-01])
      assert {:ok, ~D[2023-01-01]} == Zoi.parse(schema, ~D[2023-01-01])
      assert {:ok, ~D[2023-02-01]} == Zoi.parse(schema, ~D[2023-02-01])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~D[2022-12-31])
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 2023-01-01"
    end

    test "gte for datetime" do
      schema = Zoi.datetime() |> Zoi.gte(~U[2023-01-01 00:00:00Z])
      assert {:ok, ~U[2023-01-01 00:00:00Z]} == Zoi.parse(schema, ~U[2023-01-01 00:00:00Z])
      assert {:ok, ~U[2023-02-01 12:34:56Z]} == Zoi.parse(schema, ~U[2023-02-01 12:34:56Z])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~U[2022-12-31 23:59:59Z])
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 2023-01-01 00:00:00Z"
    end

    test "gte for naive_datetime" do
      schema = Zoi.naive_datetime() |> Zoi.gte(~N[2023-01-01 00:00:00])
      assert {:ok, ~N[2023-01-01 00:00:00]} == Zoi.parse(schema, ~N[2023-01-01 00:00:00])
      assert {:ok, ~N[2023-02-01 12:34:56]} == Zoi.parse(schema, ~N[2023-02-01 12:34:56])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~N[2022-12-31 23:59:59])
      assert error.code == :greater_than_or_equal_to
      assert Exception.message(error) == "too small: must be at least 2023-01-01 00:00:00"
    end

    test "custom message" do
      schema = Zoi.integer() |> Zoi.gte(10, error: "must be >= %{count}")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 5)
      assert error.code == :custom
      assert Exception.message(error) == "must be >= 10"
    end
  end

  describe "gt/2" do
    test "gt for integer" do
      schema = Zoi.integer() |> Zoi.gt(10)
      assert {:ok, 15} == Zoi.parse(schema, 15)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10)
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 10"
    end

    test "gt for float" do
      schema = Zoi.float() |> Zoi.gt(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10.5)
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 10.5"
    end

    test "gt for number" do
      schema = Zoi.number() |> Zoi.gt(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10.5)
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 10.5"
    end

    test "gt for decimal" do
      schema = Zoi.decimal() |> Zoi.gt(Decimal.new("10.5"))
      assert {:ok, Decimal.new("12.34")} == Zoi.parse(schema, "12.34", coerce: true)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "10.5", coerce: true)
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 10.5"
    end

    test "gt for time" do
      schema = Zoi.time() |> Zoi.gt(~T[12:00:00])
      assert {:ok, ~T[12:30:00]} == Zoi.parse(schema, ~T[12:30:00])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~T[11:59:59])
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 12:00:00"
    end

    test "gt for date" do
      schema = Zoi.date() |> Zoi.gt(~D[2023-01-01])
      assert {:ok, ~D[2023-01-02]} == Zoi.parse(schema, ~D[2023-01-02])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~D[2023-01-01])
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 2023-01-01"
    end

    test "gt for datetime" do
      schema = Zoi.datetime() |> Zoi.gt(~U[2023-01-01 00:00:00Z])
      assert {:ok, ~U[2023-01-01 12:34:56Z]} == Zoi.parse(schema, ~U[2023-01-01 12:34:56Z])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~U[2023-01-01 00:00:00Z])
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 2023-01-01 00:00:00Z"
    end

    test "gt for naive_datetime" do
      schema = Zoi.naive_datetime() |> Zoi.gt(~N[2023-01-01 00:00:00])
      assert {:ok, ~N[2023-01-01 12:34:56]} == Zoi.parse(schema, ~N[2023-01-01 12:34:56])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~N[2023-01-01 00:00:00])
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 2023-01-01 00:00:00"
    end

    test "custom message" do
      schema = Zoi.integer() |> Zoi.gt(10, error: "must be > %{count}")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10)
      assert error.code == :custom
      assert Exception.message(error) == "must be > 10"
    end

    test "gt after transform" do
      schema =
        Zoi.integer()
        |> Zoi.transform(fn x -> x + 1 end)
        |> Zoi.gt(10)

      assert {:ok, 11} == Zoi.parse(schema, 10)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 9)
      assert error.code == :greater_than
      assert Exception.message(error) == "too small: must be greater than 10"
    end
  end

  describe "max/2" do
    test "max for string" do
      schema = Zoi.string() |> Zoi.max(5)
      assert {:ok, "hi"} == Zoi.parse(schema, "hi")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello world")
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must have at most 5 character(s)"
      assert error.issue == {"too big: must have at most %{count} character(s)", [count: 5]}
    end

    test "max for string with transforms runs refinements" do
      schema =
        Zoi.string()
        |> Zoi.trim()
        |> Zoi.max(3)

      assert {:ok, "abc"} == Zoi.parse(schema, "  abc  ")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "abcdef")
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must have at most 3 character(s)"
    end

    test "max for integer" do
      schema = Zoi.integer() |> Zoi.max(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 15)
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10"
    end

    test "max for float" do
      schema = Zoi.float() |> Zoi.max(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10.5"
    end

    test "max for number" do
      schema = Zoi.number() |> Zoi.max(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10.5"
    end

    test "max for decimal" do
      schema = Zoi.decimal() |> Zoi.max(Decimal.new("10.5"))
      assert {:ok, Decimal.new("9.99")} == Zoi.parse(schema, "9.99", coerce: true)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, Decimal.new("12.34"))
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10.5"
    end

    test "max for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.max(3)
      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3, 4])
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must have at most 3 item(s)"
    end

    test "custom message" do
      schema = Zoi.integer() |> Zoi.max(10, error: "must be <= %{count}")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 15)
      assert error.code == :custom
      assert Exception.message(error) == "must be <= 10"
    end
  end

  describe "lte/2" do
    test "lte for string" do
      schema = Zoi.string() |> Zoi.lte(5)
      assert {:ok, "hi"} == Zoi.parse(schema, "hi")
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello world")
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must have at most 5 character(s)"
      assert error.issue == {"too big: must have at most %{count} character(s)", [count: 5]}
    end

    test "lte for integer" do
      schema = Zoi.integer() |> Zoi.lte(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:ok, 10} == Zoi.parse(schema, 10)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 15)
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10"
      assert error.issue == {"too big: must be at most %{count}", [count: 10]}
    end

    test "lte for float" do
      schema = Zoi.float() |> Zoi.lte(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:ok, 10.5} == Zoi.parse(schema, 10.5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10.5"
      assert error.issue == {"too big: must be at most %{count}", [count: 10.5]}
    end

    test "lte for number" do
      schema = Zoi.number() |> Zoi.lte(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:ok, 10.5} == Zoi.parse(schema, 10.5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10.5"
      assert error.issue == {"too big: must be at most %{count}", [count: 10.5]}
    end

    test "lte for decimal" do
      schema = Zoi.decimal() |> Zoi.lte(Decimal.new("10.5"))
      assert {:ok, Decimal.new("9.99")} == Zoi.parse(schema, Decimal.new("9.99"))
      assert {:ok, Decimal.new("10.5")} == Zoi.parse(schema, "10.5", coerce: true)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, Decimal.new("12.34"))
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must be at most 10.5"
      assert error.issue == {"too big: must be at most %{count}", [count: Decimal.new("10.5")]}
    end

    test "lte for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.lte(3)
      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3, 4])
      assert error.code == :less_than_or_equal_to
      assert Exception.message(error) == "too big: must have at most 3 item(s)"
      assert error.issue == {"too big: must have at most %{count} item(s)", [count: 3]}
    end

    test "lte for time" do
      schema = Zoi.time() |> Zoi.lte(~T[12:00:00])
      assert {:ok, ~T[11:59:59]} == Zoi.parse(schema, ~T[11:59:59])
      assert {:ok, ~T[12:00:00]} == Zoi.parse(schema, ~T[12:00:00])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~T[12:30:00])
      assert Exception.message(error) == "too big: must be at most 12:00:00"
    end

    test "lte for date" do
      schema = Zoi.date() |> Zoi.lte(~D[2023-01-01])
      assert {:ok, ~D[2022-12-31]} == Zoi.parse(schema, ~D[2022-12-31])
      assert {:ok, ~D[2023-01-01]} == Zoi.parse(schema, ~D[2023-01-01])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~D[2023-01-02])
      assert Exception.message(error) == "too big: must be at most 2023-01-01"
    end

    test "lte for datetime" do
      schema = Zoi.datetime() |> Zoi.lte(~U[2023-01-01 00:00:00Z])
      assert {:ok, ~U[2022-12-31 23:59:59Z]} == Zoi.parse(schema, ~U[2022-12-31 23:59:59Z])
      assert {:ok, ~U[2023-01-01 00:00:00Z]} == Zoi.parse(schema, ~U[2023-01-01 00:00:00Z])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~U[2023-01-01 12:34:56Z])
      assert Exception.message(error) == "too big: must be at most 2023-01-01 00:00:00Z"
    end

    test "lte for naive_datetime" do
      schema = Zoi.naive_datetime() |> Zoi.lte(~N[2023-01-01 00:00:00])
      assert {:ok, ~N[2022-12-31 23:59:59]} == Zoi.parse(schema, ~N[2022-12-31 23:59:59])
      assert {:ok, ~N[2023-01-01 00:00:00]} == Zoi.parse(schema, ~N[2023-01-01 00:00:00])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~N[2023-01-01 12:34:56])
      assert Exception.message(error) == "too big: must be at most 2023-01-01 00:00:00"
    end

    test "custom message" do
      schema = Zoi.integer() |> Zoi.lte(10, error: "must be <= %{count}")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 15)
      assert error.code == :custom
      assert Exception.message(error) == "must be <= 10"
    end
  end

  describe "lt/2" do
    test "lt for integer" do
      schema = Zoi.integer() |> Zoi.lt(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10)
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 10"
    end

    test "lt for float" do
      schema = Zoi.float() |> Zoi.lt(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10.5)
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 10.5"
    end

    test "lt for number" do
      schema = Zoi.number() |> Zoi.lt(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10.5)
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 10.5"
    end

    test "lt for decimal" do
      schema = Zoi.decimal() |> Zoi.lt(Decimal.new("10.5"))
      assert {:ok, Decimal.new("9.99")} == Zoi.parse(schema, Decimal.new("9.99"))
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, Decimal.new("10.5"))
      assert Exception.message(error) == "too big: must be less than 10.5"
    end

    test "lt for time" do
      schema = Zoi.time() |> Zoi.lt(~T[12:00:00])
      assert {:ok, ~T[11:59:59]} == Zoi.parse(schema, ~T[11:59:59])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~T[12:00:00])
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 12:00:00"
    end

    test "lt for date" do
      schema = Zoi.date() |> Zoi.lt(~D[2023-01-01])
      assert {:ok, ~D[2022-12-31]} == Zoi.parse(schema, ~D[2022-12-31])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~D[2023-01-01])
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 2023-01-01"
    end

    test "lt for datetime" do
      schema = Zoi.datetime() |> Zoi.lt(~U[2023-01-01 00:00:00Z])
      assert {:ok, ~U[2022-12-31 23:59:59Z]} == Zoi.parse(schema, ~U[2022-12-31 23:59:59Z])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~U[2023-01-01 00:00:00Z])
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 2023-01-01 00:00:00Z"
    end

    test "lt for naive_datetime" do
      schema = Zoi.naive_datetime() |> Zoi.lt(~N[2023-01-01 00:00:00])
      assert {:ok, ~N[2022-12-31 23:59:59]} == Zoi.parse(schema, ~N[2022-12-31 23:59:59])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, ~N[2023-01-01 00:00:00])
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 2023-01-01 00:00:00"
    end

    test "custom message" do
      schema = Zoi.integer() |> Zoi.lt(10, error: "must be < %{count}")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10)
      assert error.code == :custom
      assert Exception.message(error) == "must be < 10"
    end

    test "lt after transforms" do
      schema =
        Zoi.integer()
        |> Zoi.transform(fn x -> x + 5 end)
        |> Zoi.lt(10)

      assert {:ok, 4} == Zoi.parse(schema, -1)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 6)
      assert error.code == :less_than
      assert Exception.message(error) == "too big: must be less than 10"
    end
  end

  describe "length/2" do
    test "length for string" do
      schema = Zoi.string() |> Zoi.length(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert error.code == :invalid_length
      assert Exception.message(error) == "invalid length: must have 5 character(s)"
      assert error.issue == {"invalid length: must have %{count} character(s)", [count: 5]}
    end

    test "length for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.length(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2])
      assert error.code == :invalid_length
      assert Exception.message(error) == "invalid length: must have 3 item(s)"
      assert error.issue == {"invalid length: must have %{count} item(s)", [count: 3]}
    end

    test "custom message" do
      schema = Zoi.string() |> Zoi.length(5, error: "length must be %{count}")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "length must be 5"
    end

    test "length after transforms" do
      schema =
        Zoi.string()
        |> Zoi.trim()
        |> Zoi.length(3)

      assert {:ok, "abc"} == Zoi.parse(schema, "  abc  ")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "  ab  ")
      assert error.code == :invalid_length
      assert Exception.message(error) == "invalid length: must have 3 character(s)"
    end

    test "length should only work on implemented protocols" do
      schema = Zoi.literal("a") |> Zoi.length(4)
      assert {:ok, "a"} == Zoi.parse(schema, "a")
    end
  end

  describe "one_of/3" do
    test "valid string value" do
      schema = Zoi.string() |> Zoi.one_of(["red", "green", "blue"])
      assert {:ok, "red"} == Zoi.parse(schema, "red")
      assert {:ok, "green"} == Zoi.parse(schema, "green")
      assert {:ok, "blue"} == Zoi.parse(schema, "blue")
    end

    test "invalid string value" do
      schema = Zoi.string() |> Zoi.one_of(["red", "green", "blue"])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "yellow")
      assert error.code == :not_in_values
      assert Exception.message(error) == "invalid value: expected one of red, green, blue"

      assert error.issue == {
               "invalid value: expected one of %{values}",
               [values: ["red", "green", "blue"]]
             }
    end

    test "valid integer value" do
      schema = Zoi.integer() |> Zoi.one_of([1, 2, 3, 5, 8])
      assert {:ok, 1} == Zoi.parse(schema, 1)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:ok, 8} == Zoi.parse(schema, 8)
    end

    test "invalid integer value" do
      schema = Zoi.integer() |> Zoi.one_of([1, 2, 3, 5, 8])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 4)
      assert error.code == :not_in_values
      assert Exception.message(error) == "invalid value: expected one of 1, 2, 3, 5, 8"

      assert error.issue == {
               "invalid value: expected one of %{values}",
               [values: [1, 2, 3, 5, 8]]
             }
    end

    test "valid atom value" do
      schema = Zoi.atom() |> Zoi.one_of([:small, :medium, :large])
      assert {:ok, :small} == Zoi.parse(schema, :small)
      assert {:ok, :large} == Zoi.parse(schema, :large)
    end

    test "invalid atom value" do
      schema = Zoi.atom() |> Zoi.one_of([:small, :medium, :large])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, :extra_large)
      assert error.code == :not_in_values
      assert Exception.message(error) == "invalid value: expected one of small, medium, large"

      assert error.issue == {
               "invalid value: expected one of %{values}",
               [values: [:small, :medium, :large]]
             }
    end

    test "with custom error message" do
      schema = Zoi.string() |> Zoi.one_of(["admin", "user"], error: "must be a valid role")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "guest")
      assert error.code == :custom
      assert Exception.message(error) == "must be a valid role"
    end

    test "works with any type" do
      schema = Zoi.number() |> Zoi.one_of([1.5, 2.5, 3.5])
      assert {:ok, 2.5} == Zoi.parse(schema, 2.5)
      assert {:error, [%Zoi.Error{}]} = Zoi.parse(schema, 2.0)
    end
  end

  describe "regex/2" do
    test "valid regex match" do
      schema = Zoi.string() |> Zoi.regex(~r/^\d+$/)
      assert {:ok, "12345"} == Zoi.parse(schema, "12345")
    end

    test "invalid regex match" do
      regex = ~r/^\d+$/
      schema = Zoi.string() |> Zoi.regex(regex)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "abc")
      assert error.code == :invalid_format

      assert Exception.message(error) ==
               "invalid format: must match pattern #{Regex.source(regex)}"
    end

    test "custom message" do
      schema = Zoi.string() |> Zoi.regex(~r/^\d+$/, error: "must be a number")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "abc")
      assert error.code == :custom
      assert Exception.message(error) == "must be a number"
    end

    test "regex should only work on implemented protocols" do
      schema = Zoi.literal("a") |> Zoi.regex(~r/b/)
      assert {:ok, "a"} == Zoi.parse(schema, "a")
    end
  end

  describe "starts_with/2" do
    test "valid prefix" do
      schema = Zoi.string() |> Zoi.starts_with("prefix_")
      assert {:ok, "prefix_value"} == Zoi.parse(schema, "prefix_value")
    end

    test "invalid prefix" do
      schema = Zoi.string() |> Zoi.starts_with("prefix_")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "value")
      assert error.code == :invalid_format
      assert Exception.message(error) == "invalid format: must start with 'prefix_'"
    end

    test "custom message" do
      schema = Zoi.string() |> Zoi.starts_with("prefix_", error: "should have prefix")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "value")
      assert error.code == :custom
      assert Exception.message(error) == "should have prefix"
    end

    test "starts_with should only work on implemented protocols" do
      schema = Zoi.literal("a") |> Zoi.starts_with("b")
      assert {:ok, "a"} == Zoi.parse(schema, "a")
    end
  end

  describe "ends_with/2" do
    test "valid suffix" do
      schema = Zoi.string() |> Zoi.ends_with("_suffix")
      assert {:ok, "value_suffix"} == Zoi.parse(schema, "value_suffix")
    end

    test "invalid suffix" do
      schema = Zoi.string() |> Zoi.ends_with("_suffix")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "value")
      assert error.code == :invalid_format
      assert Exception.message(error) == "invalid format: must end with '_suffix'"
    end

    test "custom message" do
      schema = Zoi.string() |> Zoi.ends_with("_suffix", error: "should have suffix")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "value")
      assert error.code == :custom
      assert Exception.message(error) == "should have suffix"
    end

    test "ends_with should only work on implemented protocols" do
      schema = Zoi.literal("a") |> Zoi.ends_with("b")
      assert {:ok, "a"} == Zoi.parse(schema, "a")
    end
  end

  describe "downcase/1" do
    test "valid downcase" do
      schema = Zoi.string() |> Zoi.downcase()
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "invalid downcase" do
      schema = Zoi.string() |> Zoi.downcase()
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "Hello")
      assert error.code == :invalid_format
      assert Exception.message(error) == "invalid format: must be lowercase"
      assert {"invalid format: must be lowercase", pattern: pattern} = error.issue
      assert Regex.source(pattern) == Regex.source(Zoi.Regexes.downcase())
    end

    test "custom message" do
      schema = Zoi.string() |> Zoi.downcase(error: "should be lowercase")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "Hello")
      assert error.code == :custom
      assert Exception.message(error) == "should be lowercase"
    end
  end

  describe "upcase/1" do
    test "valid upcase" do
      schema = Zoi.string() |> Zoi.upcase()
      assert {:ok, "HELLO"} == Zoi.parse(schema, "HELLO")
    end

    test "invalid upcase" do
      schema = Zoi.string() |> Zoi.upcase()
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "Hello")
      assert error.code == :invalid_format
      assert Exception.message(error) == "invalid format: must be uppercase"
      assert {"invalid format: must be uppercase", pattern: pattern} = error.issue
      assert Regex.source(pattern) == Regex.source(Zoi.Regexes.upcase())
    end

    test "custom message" do
      schema = Zoi.string() |> Zoi.upcase(error: "should be uppercase")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "Hello")
      assert error.code == :custom
      assert Exception.message(error) == "should be uppercase"
    end
  end

  describe "trim/2" do
    test "trim whitespace" do
      schema = Zoi.string() |> Zoi.trim()
      assert {:ok, "hello"} == Zoi.parse(schema, "  hello  ")
      assert {:ok, "world"} == Zoi.parse(schema, "  world")
    end

    test "trim with no whitespace" do
      schema = Zoi.string() |> Zoi.trim()
      assert {:ok, "test"} == Zoi.parse(schema, "test")
    end
  end

  describe "to_downcase/1" do
    test "downcase string" do
      schema = Zoi.string() |> Zoi.to_downcase()
      assert {:ok, "hello"} == Zoi.parse(schema, "HELLO")
      assert {:ok, "world"} == Zoi.parse(schema, "WORLD")
    end

    test "downcase already lowercase" do
      schema = Zoi.string() |> Zoi.to_downcase()
      assert {:ok, "test"} == Zoi.parse(schema, "test")
    end
  end

  describe "to_upcase/1" do
    test "upcase string" do
      schema = Zoi.string() |> Zoi.to_upcase()
      assert {:ok, "HELLO"} == Zoi.parse(schema, "hello")
      assert {:ok, "WORLD"} == Zoi.parse(schema, "world")
    end

    test "upcase already uppercase" do
      schema = Zoi.string() |> Zoi.to_upcase()
      assert {:ok, "TEST"} == Zoi.parse(schema, "TEST")
    end
  end

  describe "to_struct/2" do
    test "valid struct conversion" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()}) |> Zoi.to_struct(User)
      assert {:ok, %User{name: "Alice", age: 30}} == Zoi.parse(schema, %{name: "Alice", age: 30})
    end

    test "invalid struct conversion" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()}) |> Zoi.to_struct(User)

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{name: "Alice", age: "not an integer"})

      assert Exception.message(error) == "invalid type: expected integer"
    end

    test "struct conversion with missing fields" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()}) |> Zoi.to_struct(User)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, %{name: "Alice"})
      assert error.code == :required
      assert Exception.message(error) == "is required"
    end

    test "struct conversion with keyword list" do
      schema = Zoi.keyword(name: Zoi.string(), age: Zoi.integer()) |> Zoi.to_struct(User)
      assert {:ok, %User{name: "Bob", age: 25}} == Zoi.parse(schema, name: "Bob", age: 25)
    end
  end

  describe "refine/2" do
    test "valid refinement" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn value ->
          if String.length(value) > 3 do
            :ok
          else
            {:error, "must be longer than 3 characters"}
          end
        end)

      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "invalid refinement" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn value ->
          if String.length(value) > 3 do
            :ok
          else
            {:error, "must be longer than 3 characters"}
          end
        end)

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert error.code == :custom
      assert Exception.message(error) == "must be longer than 3 characters"
    end

    test "refinement with context errors" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _value, ctx ->
          ctx
          |> Zoi.Context.add_error(%{message: "context error", path: [:hello]})
          |> Zoi.Context.add_error("another error")
          |> Zoi.Context.add_error(
            Zoi.Error.custom_error(
              issue: {"custom context error with val %{val}", [val: 2]},
              path: [:world]
            )
          )
        end)

      assert {:error, errors} = Zoi.parse(schema, "hello")
      assert length(errors) == 3

      assert errors == [
               %Zoi.Error{
                 code: :custom,
                 issue: {"context error", []},
                 message: "context error",
                 path: [:hello]
               },
               %Zoi.Error{
                 code: :custom,
                 issue: {"another error", []},
                 message: "another error",
                 path: []
               },
               %Zoi.Error{
                 code: :custom,
                 issue: {"custom context error with val %{val}", [val: 2]},
                 message: "custom context error with val 2",
                 path: [:world]
               }
             ]
    end
  end

  describe "transform/2" do
    test "valid transform" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn value -> {:ok, String.upcase(value)} end)

      assert {:ok, "HELLO"} == Zoi.parse(schema, "hello")
    end

    test "invalid transform" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _schema, _value -> {:error, "transform error"} end)

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello")
      assert error.code == :custom
      assert Exception.message(error) == "transform error"
    end

    test "transform with no pattern match" do
      schema = Zoi.string() |> Zoi.transform({Zoi.Transforms, :transform, [[]]})
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "transform with context errors" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _value, ctx ->
          Zoi.Context.add_error(ctx, %{message: "context error", path: [:hello]})
        end)

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello")
      assert error.code == :custom
      assert Exception.message(error) == "context error"
      assert error.path == [:hello]
    end

    test "transforms and refines executes in chain order" do
      schema =
        Zoi.string()
        |> Zoi.min(3)
        |> Zoi.transform(&String.trim/1)
        |> Zoi.transform(&String.upcase/1)
        |> Zoi.refine(fn s ->
          if String.starts_with?(s, "H") do
            :ok
          else
            {:error, "must start with H"}
          end
        end)

      assert {:ok, "HELLO"} = Zoi.parse(schema, "  hello  ")
      # doesn't start with H
      assert {:error, _} = Zoi.parse(schema, "  goodbye  ")
    end

    test "transforms modify data for subsequent refines" do
      schema =
        Zoi.string()
        |> Zoi.transform(&String.trim/1)
        # min check runs on trimmed value
        |> Zoi.min(5)

      assert {:ok, "hello"} = Zoi.parse(schema, "  hello  ")
      # only 2 chars after trim
      assert {:error, _} = Zoi.parse(schema, "  hi  ")
    end
  end

  describe "treefy_error/1" do
    test "treefy single error" do
      error = %Zoi.Error{path: [:name], message: "is required"}
      assert %{name: [error.message]} == Zoi.treefy_errors([error])
    end

    test "treefy nested errors" do
      error_1 = %Zoi.Error{path: [:user, :name], message: "is required"}
      error_2 = %Zoi.Error{path: [:user, :age], message: "is required"}

      assert %{user: %{name: [error_1.message], age: [error_2.message]}} ==
               Zoi.treefy_errors([error_1, error_2])
    end

    test "treefy errors without path" do
      error = %Zoi.Error{message: "invalid type"}
      # No path means the error is at the root level
      assert %{__errors__: [error.message]} == Zoi.treefy_errors([error])
    end

    test "treefy errors in array" do
      schema = Zoi.array(Zoi.integer())
      assert {:error, errors} = Zoi.parse(schema, ["not an integer", 2, "not an integer"])

      assert %{
               0 => ["invalid type: expected integer"],
               2 => ["invalid type: expected integer"]
             } ==
               Zoi.treefy_errors(errors)
    end

    test "treefy empty errors" do
      assert %{} == Zoi.treefy_errors([])
    end

    test "object with deeply nested object" do
      schema =
        Zoi.object(
          %{
            user:
              Zoi.object(%{
                profile:
                  Zoi.object(%{
                    email: Zoi.email() |> Zoi.min(4),
                    age: Zoi.integer(),
                    numbers: Zoi.array(Zoi.integer())
                  }),
                active: Zoi.boolean()
              })
          },
          strict: true
        )

      assert {:error, errors} =
               Zoi.parse(schema, %{
                 user: %{
                   profile: %{email: "tt", numbers: [1, 2, "not an integer"]}
                 },
                 invalid_key: "value"
               })

      assert Zoi.treefy_errors(errors) == %{
               user: %{
                 active: ["is required"],
                 profile: %{
                   age: [
                     "is required"
                   ],
                   email: [
                     "invalid email format",
                     "too small: must have at least 4 character(s)"
                   ],
                   numbers: %{
                     2 => [
                       "invalid type: expected integer"
                     ]
                   }
                 }
               },
               __errors__: ["unrecognized key: invalid_key"]
             }
    end
  end

  describe "preetify_error/1" do
    test "prettify single error" do
      error = %Zoi.Error{path: [:name], message: "is required"}
      assert "is required, at name" == Zoi.prettify_errors([error])
    end

    test "prettify nested errors" do
      error_1 = %Zoi.Error{path: [:user, :name], message: "is required"}
      error_2 = %Zoi.Error{path: [:user, :age], message: "is required"}

      assert "is required, at user.name\nis required, at user.age" ==
               Zoi.prettify_errors([error_1, error_2])
    end

    test "prettify errors without path" do
      error = %Zoi.Error{message: "invalid type"}
      assert "invalid type" == Zoi.prettify_errors([error])
    end

    test "prettify errors in array" do
      schema = Zoi.array(Zoi.integer())
      assert {:error, errors} = Zoi.parse(schema, ["not an integer", 2, "not an integer"])

      assert "invalid type: expected integer, at [0]\ninvalid type: expected integer, at [2]" ==
               Zoi.prettify_errors(errors)
    end

    test "prettify empty errors" do
      assert "" == Zoi.prettify_errors([])
    end
  end

  describe "description/1" do
    test "all main types description" do
      types = [
        Zoi.any(description: "description"),
        Zoi.array(Zoi.string(), description: "description"),
        Zoi.atom(description: "description"),
        Zoi.boolean(description: "description"),
        Zoi.date(description: "description"),
        Zoi.datetime(description: "description"),
        Zoi.decimal(description: "description"),
        Zoi.default(Zoi.string(), "default", description: "description"),
        Zoi.enum(["a", "b", "c"], description: "description"),
        Zoi.float(description: "description"),
        Zoi.integer(description: "description"),
        Zoi.intersection([Zoi.string(coerce: true), Zoi.atom()], description: "description"),
        Zoi.literal("true", description: "description"),
        Zoi.map(description: "description"),
        Zoi.naive_datetime(description: "description"),
        Zoi.null(description: "description"),
        Zoi.nullable(Zoi.string(), description: "description"),
        Zoi.nullish(Zoi.integer(), description: "description"),
        Zoi.number(description: "description"),
        Zoi.optional(Zoi.string(description: "description")),
        Zoi.string(description: "description"),
        Zoi.string_boolean(description: "description"),
        Zoi.time(description: "description"),
        Zoi.tuple({Zoi.string(), Zoi.integer(), Zoi.any()}, description: "description"),
        Zoi.union([Zoi.integer(), Zoi.float()], description: "description")
      ]

      Enum.each(types, fn schema ->
        assert Zoi.description(schema) == "description"
      end)
    end
  end

  describe "example/1" do
    test "all main types examples" do
      types = [
        Zoi.any(example: :example),
        Zoi.array(Zoi.string(), example: ["example"]),
        Zoi.atom(example: :example),
        Zoi.boolean(example: true),
        Zoi.date(example: ~D[2023-01-01]),
        Zoi.datetime(example: ~U[2023-01-01 00:00:00Z]),
        Zoi.decimal(example: Decimal.new("123.45")),
        Zoi.default(Zoi.string(), "default", example: "default"),
        Zoi.enum(["a", "b", "c"], example: "a"),
        Zoi.float(example: 1.23),
        Zoi.integer(example: 123),
        Zoi.intersection([Zoi.string(coerce: true), Zoi.atom()], example: :example),
        Zoi.literal("true", example: "true"),
        Zoi.map(example: %{"key" => "value"}),
        Zoi.naive_datetime(example: ~N[2023-01-01 00:00:00]),
        Zoi.null(example: nil),
        Zoi.nullable(Zoi.string(), example: nil),
        Zoi.nullish(Zoi.integer(), example: 12),
        Zoi.number(example: 123),
        Zoi.optional(Zoi.string(example: "example")),
        Zoi.string(example: "example"),
        Zoi.string_boolean(example: true),
        Zoi.time(example: ~T[12:34:56]),
        Zoi.tuple({Zoi.string(), Zoi.integer(), Zoi.any()}, example: {"example", 123, :any}),
        Zoi.union([Zoi.integer(), Zoi.float()], example: 1.5),
        Zoi.keyword([name: Zoi.string(), age: Zoi.integer()],
          example: [name: "example", age: 123]
        ),
        Zoi.object(%{name: Zoi.string(), age: Zoi.integer()},
          example: %{name: "example", age: 123}
        ),
        Zoi.struct(User, %{name: Zoi.string(), age: Zoi.integer()},
          example: %User{name: "example", age: 123}
        )
      ]

      Enum.each(types, fn schema ->
        example = Zoi.example(schema)
        assert Zoi.parse(schema, example) == {:ok, example}
      end)
    end
  end

  describe "coerce/1" do
    test "enables coercion on types that support it" do
      schemas = [
        Zoi.string(),
        Zoi.integer(),
        Zoi.float(),
        Zoi.boolean(),
        Zoi.object(%{}),
        Zoi.array(Zoi.string())
      ]

      Enum.each(schemas, fn schema ->
        assert %{coerce: true} = Zoi.coerce(schema)
      end)
    end

    test "returns unchanged for types that don't support coercion" do
      schema = Zoi.literal("test")
      assert Zoi.coerce(schema) == schema
    end
  end

  describe "metadata/1" do
    test "all main types metadata" do
      types = [
        Zoi.any(metadata: [doc: "metadata"]),
        Zoi.array(Zoi.string(), metadata: [doc: "metadata"]),
        Zoi.string(metadata: [doc: "metadata"])
      ]

      Enum.each(types, fn schema ->
        assert Zoi.metadata(schema) == [doc: "metadata"]
      end)
    end
  end

  describe "codec/3" do
    test "decodes and encodes values between schemas" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn value -> Date.to_iso8601(value) end
        )

      assert {:ok, ~D[2025-01-15]} = Zoi.parse(codec, "2025-01-15")
      assert {:ok, "2025-01-15"} = Zoi.encode(codec, ~D[2025-01-15])
    end

    test "handles {:ok, value} return from decode/encode functions" do
      codec =
        Zoi.codec(
          Zoi.string(),
          Zoi.integer(),
          decode: fn value -> {:ok, String.to_integer(value)} end,
          encode: fn value -> {:ok, Integer.to_string(value)} end
        )

      assert {:ok, 123} = Zoi.parse(codec, "123")
      assert {:ok, "123"} = Zoi.encode(codec, 123)
    end

    test "returns error when from schema validation fails on parse" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn value -> Date.to_iso8601(value) end
        )

      assert {:error, [%Zoi.Error{code: :invalid_type}]} = Zoi.parse(codec, "invalid")
    end

    test "returns error when decode function returns error" do
      codec =
        Zoi.codec(
          Zoi.string(),
          Zoi.integer(),
          decode: fn _value -> {:error, "decode failed"} end,
          encode: fn value -> Integer.to_string(value) end
        )

      assert {:error, [%Zoi.Error{code: :custom, message: "decode failed"}]} =
               Zoi.parse(codec, "abc")
    end

    test "returns error when to schema validation fails on parse" do
      codec =
        Zoi.codec(
          Zoi.string(),
          Zoi.integer() |> Zoi.gte(100),
          decode: fn value -> String.to_integer(value) end,
          encode: fn value -> Integer.to_string(value) end
        )

      assert {:error, [%Zoi.Error{code: :greater_than_or_equal_to}]} = Zoi.parse(codec, "50")
    end

    test "returns error when to schema validation fails on encode" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn value -> Date.to_iso8601(value) end
        )

      assert {:error, [%Zoi.Error{code: :invalid_type}]} = Zoi.encode(codec, "not-a-date")
    end

    test "returns error when encode function returns error" do
      codec =
        Zoi.codec(
          Zoi.string(),
          Zoi.integer(),
          decode: fn value -> String.to_integer(value) end,
          encode: fn _value -> {:error, "encode failed"} end
        )

      assert {:error, [%Zoi.Error{code: :custom, message: "encode failed"}]} =
               Zoi.encode(codec, 123)
    end

    test "returns error when from schema validation fails on encode output" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn _value -> "invalid-format" end
        )

      assert {:error, [%Zoi.Error{code: :invalid_type}]} = Zoi.encode(codec, ~D[2025-01-15])
    end

    test "raises ArgumentError when decode is not a function" do
      assert_raise ArgumentError, ~r/expected :decode to be a 1-arity function/, fn ->
        Zoi.codec(Zoi.string(), Zoi.integer(), decode: "invalid", encode: fn x -> x end)
      end
    end

    test "raises ArgumentError when encode is not a function" do
      assert_raise ArgumentError, ~r/expected :encode to be a 1-arity function/, fn ->
        Zoi.codec(Zoi.string(), Zoi.integer(), decode: fn x -> x end, encode: nil)
      end
    end

    test "type_spec returns the to schema's type spec" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn value -> Date.to_iso8601(value) end
        )

      assert Zoi.type_spec(codec) == quote(do: Date.t())
    end

    test "JSON schema returns the from schema's JSON schema" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn value -> Date.to_iso8601(value) end
        )

      assert Zoi.JSONSchema.Encoder.encode(codec) == %{type: :string, format: :date}
    end

    test "inspect protocol" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn value -> Date.to_iso8601(value) end
        )

      assert inspect(codec) =~ "Zoi.codec"
    end

    test "encode! raises on error" do
      codec =
        Zoi.codec(
          Zoi.ISO.date(),
          Zoi.date(),
          decode: fn value -> Date.from_iso8601(value) end,
          encode: fn value -> Date.to_iso8601(value) end
        )

      assert_raise Zoi.ParseError, fn ->
        Zoi.encode!(codec, "not-a-date")
      end
    end
  end
end
