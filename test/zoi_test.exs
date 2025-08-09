defmodule ZoiTest do
  use ExUnit.Case
  doctest Zoi

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

      assert Exception.message(error) == "invalid type: must be a string"
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
        assert Exception.message(error) == "invalid type: must be an integer"
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

      assert Exception.message(error) == "invalid type: must be an integer"
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
        assert Exception.message(error) == "invalid type: must be a float"
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

      assert Exception.message(error) == "invalid type: must be a float"
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
        assert Exception.message(error) == "invalid type: must be a number"
      end
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
        assert Exception.message(error) == "invalid type: must be a boolean"
      end
    end

    test "boolean with coercion" do
      thruth_values = ["true", "1", "yes", "on", "y", "enabled"]

      for value <- thruth_values do
        assert {:ok, true} == Zoi.parse(Zoi.boolean(), value, coerce: true)
      end

      false_values = ["false", "0", "no", "off", "n", "disabled"]

      for value <- false_values do
        assert {:ok, false} == Zoi.parse(Zoi.boolean(), value, coerce: true)
      end
    end

    test "invalid boolean with coercion" do
      wrong_values = ["True", "False", 1, 0]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.boolean(), value, coerce: true)
        assert Exception.message(error) == "invalid type: must be a boolean"
      end
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

  describe "optional/2" do
    test "optional with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.optional(Zoi.string()), "hello")
    end

    test "optional should fail if send `nil` value" do
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.optional(Zoi.string()), nil)
      assert Exception.message(error) == "invalid type: must be a string"
    end

    test "optional with incorrect type" do
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.optional(Zoi.string()), 123)
      assert Exception.message(error) == "invalid type: must be a string"
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
      assert Exception.message(error) == "invalid type: must be a string"
    end
  end

  describe "default/2" do
    test "default with correct value" do
      schema = Zoi.default(Zoi.string(), "default_value")

      assert {:ok, "default_value"} == Zoi.parse(schema, nil)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end

    test "default with incorrect type" do
      assert_raise ArgumentError,
                   "Invalid default value: \"10\". Reason: invalid type: must be an integer",
                   fn ->
                     Zoi.default(Zoi.integer(), "10")
                   end
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
      assert Exception.message(error) == "invalid type: must be an integer"
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
      assert_raise ArgumentError, "Union type must be receive a list of minimum 2 schemas", fn ->
        Zoi.union([])
      end

      assert_raise ArgumentError, "Union type must be receive a list of minimum 2 schemas", fn ->
        Zoi.union([Zoi.string()])
      end
    end

    test "union with incorrect type" do
      assert_raise ArgumentError, "Union type must be receive a list of minimum 2 schemas", fn ->
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
      assert Exception.message(error) == "invalid type: must be an integer"

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
      assert Exception.message(error) == "invalid type: must be an integer"
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
      assert Exception.message(error) == "invalid string: must start with 'prefix_'"
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
        |> Zoi.trim()

      assert {:ok, "prefix_value_suffix"} == Zoi.parse(schema, "  prefix_value_suffix  ")

      # Fails on `starts_with` refinement, fallback to string validation
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "value_without_suffix")
      assert Exception.message(error) == "invalid string: must start with 'prefix_'"
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
      assert Exception.message(error) == "invalid string: must start with 'prefix_'"

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "prefix_suffix")
      assert Exception.message(error) == "too small: must have at least 14 characters"
    end
  end

  describe "object/2" do
    test "object with correct value" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:ok, %{name: "John", age: 30}} ==
               Zoi.parse(schema, %{
                 "name" => "John",
                 "age" => 30
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
                 "name" => "John"
               })

      assert Exception.message(error) == "is required"
      assert error.path == [:age]
    end

    test "object with incorrect values" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 "name" => "John",
                 "age" => "not an integer"
               })

      assert Exception.message(error) == "invalid type: must be an integer"
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
                 "name" => "John"
               })
    end

    test "object with non-map input" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a map")
      assert Exception.message(error) == "invalid type: must be a map"
    end

    test "object with nested object" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string(), age: Zoi.integer()}),
          active: Zoi.boolean()
        })

      assert {:ok, %{user: %{name: "Alice", age: 25}, active: true}} ==
               Zoi.parse(schema, %{
                 "user" => %{"name" => "Alice", "age" => 25},
                 "active" => true
               })

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{
                 "user" => %{"name" => "Alice"},
                 "active" => true
               })

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

      assert {:ok, %{name: "John"}} == Zoi.parse(schema, %{"name" => "John"})

      assert {:error, errors} =
               Zoi.parse(
                 schema,
                 %{
                   "name" => "John",
                   "age" => 30,
                   "address" => %{"wrong key" => "value"},
                   "phone" => %{"wrong key" => "value"}
                 }
               )

      assert ^errors = [
               %Zoi.Error{message: "unrecognized key: 'wrong key'", path: [:phone]},
               %Zoi.Error{message: "unrecognized key: 'age'", path: []}
             ]
    end
  end

  describe "map/3" do
    test "map with correct values" do
      schema = Zoi.map(Zoi.string(), Zoi.integer())

      assert {:ok, %{"key1" => 1, "key2" => 2}} ==
               Zoi.parse(schema, %{"key1" => 1, "key2" => 2})
    end

    test "map with incorrect key type" do
      schema = Zoi.map(Zoi.string(), Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{:key_1 => 1, "key2" => 2})

      assert Exception.message(error) == "invalid type: must be a string"
      assert error.path == [:key_1]
    end

    test "map with incorrect value type" do
      schema = Zoi.map(Zoi.string(), Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, %{"key1" => "not an integer", "key2" => 2})

      assert Exception.message(error) == "invalid type: must be an integer"
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
      assert Exception.message(error) == "invalid type: must be a map"
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

      assert Exception.message(error) == "invalid type: must be an integer"
      assert error.path == [1]
    end

    test "wrong input data for tuple" do
      schema = Zoi.tuple({Zoi.string(), Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a tuple")
      assert Exception.message(error) == "invalid type: must be a tuple with 2 elements"
    end

    test "typle length difference" do
      schema = Zoi.tuple({Zoi.string(), Zoi.integer()})
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, {"hello", "world", 10})
      assert Exception.message(error) == "invalid type: must be a tuple with 2 elements"
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
               %Zoi.Error{message: "invalid type: must be an integer", path: [0, 1]},
               %Zoi.Error{message: "invalid type: must be a boolean", path: [1, 0]},
               %Zoi.Error{message: "invalid type: must be an integer", path: [1, 1, 2]}
             ]
    end
  end

  describe "array/2" do
    test "array with correct values" do
      schema = Zoi.array(Zoi.integer())

      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
    end

    test "array with incorrect value" do
      schema = Zoi.array(Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, "not an integer", 3])
      assert Exception.message(error) == "invalid type: must be an integer"
      assert error.path == [1]
    end

    test "array with empty array" do
      schema = Zoi.array(Zoi.string())

      assert {:ok, []} == Zoi.parse(schema, [])
    end

    test "array with non-array input" do
      schema = Zoi.array(Zoi.string())

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not an array")
      assert Exception.message(error) == "invalid type: must be an array"
    end

    test "array with nested arrays" do
      schema = Zoi.array(Zoi.array(Zoi.integer()))

      assert {:ok, [[1, 2], [3, 4]]} == Zoi.parse(schema, [[1, 2], [3, 4]])
    end

    test "array with nested arrays and incorrect value" do
      schema = Zoi.array(Zoi.array(Zoi.integer()))

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, [[1, 2], ["not an integer", 4]])

      assert Exception.message(error) == "invalid type: must be an integer"
      assert error.path == [0, 1]
    end

    test "array with deeply nested arrays" do
      schema = Zoi.array(Zoi.array(Zoi.array(Zoi.integer())))

      assert {:ok, [[[1], [2]], [[3], [4]]]} ==
               Zoi.parse(schema, [[[1], [2]], [[3], [4]]])

      assert {:error, [%Zoi.Error{} = error_1, %Zoi.Error{} = error_2]} =
               Zoi.parse(schema, [[[1], ["not an integer"]], [[3], [4, "not an integer"]]])

      assert Exception.message(error_1) == "invalid type: must be an integer"
      assert error_1.path == [0, 1, 0]

      assert Exception.message(error_2) == "invalid type: must be an integer"
      assert error_2.path == [1, 1, 1]
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

    test "enum with incorrect value" do
      schema = Zoi.enum([:apple, :banana, :cherry])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, :orange)
      assert Exception.message(error) == "invalid option, must be one of: apple, banana, cherry"
    end

    test "enum parse with incorrect type" do
      schema = Zoi.enum([:apple, :banana, :cherry])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "banana")
      assert Exception.message(error) == "invalid option, must be one of: apple, banana, cherry"
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
  end

  describe "decimal/1" do
    test "decimal with correct value" do
      schema = Zoi.decimal()

      assert {:ok, Decimal.new("12.34")} == Zoi.parse(schema, "12.34")
      assert {:ok, Decimal.new("42.00")} == Zoi.parse(schema, "42.00")
      assert {:ok, Decimal.new("0.0")} == Zoi.parse(schema, "0.0")
      assert {:ok, Decimal.new("-1.0")} == Zoi.parse(schema, "-1.0")
    end

    test "decimal with incorrect value" do
      wrong_values = ["12asdf", nil, "9.a", :"12", "not a decimal"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.decimal(), value)
        assert Exception.message(error) == "invalid type: must be a decimal"
      end
    end

    test "decimal with coercion but incorrect value" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.decimal(), "not_decimal", coerce: true)

      assert Exception.message(error) == "invalid type: must be a decimal"
    end

    test "decimal with custom error" do
      schema = Zoi.decimal(error: "custom decimal error")

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a decimal")
      assert Exception.message(error) == "custom decimal error"
    end
  end

  describe "email/0" do
    test "valid email" do
      assert {:ok, "test@test.com"} == Zoi.parse(Zoi.email(), "test@test.com")
    end

    test "invalid email" do
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.email(), "invalid-email")
      assert Exception.message(error) == "invalid email format"
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
        assert Exception.message(error) == "invalid UUID format"
      end
    end
  end

  describe "url/0" do
    test "valid URL" do
      schema = Zoi.url()
      assert {:ok, "https://example.com"} == Zoi.parse(schema, "https://example.com")
      assert {:ok, "http://localhost"} == Zoi.parse(schema, "http://localhost")
    end

    test "invalid URL" do
      schema = Zoi.url()
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a url")
      assert Exception.message(error) == "invalid URL"
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
        assert Exception.message(error) == "invalid IPv6 address"
      end
    end
  end

  describe "min/2" do
    test "min for string" do
      schema = Zoi.string() |> Zoi.min(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "too small: must have at least 5 characters"
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

    test "min for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.min(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2])
      assert Exception.message(error) == "too small: must have at least 3 items"
    end
  end

  describe "gte/2" do
    test "gte for string" do
      schema = Zoi.string() |> Zoi.gte(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "too small: must have at least 5 characters"
    end

    test "gte for integer" do
      schema = Zoi.integer() |> Zoi.gte(10)
      assert {:ok, 15} == Zoi.parse(schema, 15)
      assert {:ok, 10} == Zoi.parse(schema, 10)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 5)
      assert Exception.message(error) == "too small: must be at least 10"
    end

    test "gte for float" do
      schema = Zoi.float() |> Zoi.gte(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:ok, 10.5} == Zoi.parse(schema, 10.5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 9.99)
      assert Exception.message(error) == "too small: must be at least 10.5"
    end

    test "gte for decimal" do
      schema = Zoi.decimal() |> Zoi.gte(Decimal.new("10.5"))
      assert {:ok, Decimal.new("12.34")} == Zoi.parse(schema, "12.34")
      assert {:ok, Decimal.new("10.5")} == Zoi.parse(schema, "10.5")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "9.99")
      assert Exception.message(error) == "too small: must be at least 10.5"
    end

    test "gte for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.gte(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1])
      assert Exception.message(error) == "too small: must have at least 3 items"
    end
  end

  describe "gt/2" do
    test "gt for string" do
      schema = Zoi.string() |> Zoi.gt(5)
      assert {:ok, "hello world"} == Zoi.parse(schema, "hello world")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "too small: must have more than 5 characters"
    end

    test "gt for integer" do
      schema = Zoi.integer() |> Zoi.gt(10)
      assert {:ok, 15} == Zoi.parse(schema, 15)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10)
      assert Exception.message(error) == "too small: must be greater than 10"
    end

    test "gt for float" do
      schema = Zoi.float() |> Zoi.gt(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10.5)
      assert Exception.message(error) == "too small: must be greater than 10.5"
    end

    test "gt for decimal" do
      schema = Zoi.decimal() |> Zoi.gt(Decimal.new("10.5"))
      assert {:ok, Decimal.new("12.34")} == Zoi.parse(schema, "12.34")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "10.5")
      assert Exception.message(error) == "too small: must be greater than 10.5"
    end

    test "gt for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.gt(3)
      assert {:ok, [1, 2, 3, 4]} == Zoi.parse(schema, [1, 2, 3, 4])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2])
      assert Exception.message(error) == "too small: must have more than 3 items"
    end
  end

  describe "max/2" do
    test "max for string" do
      schema = Zoi.string() |> Zoi.max(5)
      assert {:ok, "hi"} == Zoi.parse(schema, "hi")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello world")
      assert Exception.message(error) == "too big: must have at most 5 characters"
    end

    test "max for integer" do
      schema = Zoi.integer() |> Zoi.max(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 15)
      assert Exception.message(error) == "too big: must be at most 10"
    end

    test "max for float" do
      schema = Zoi.float() |> Zoi.max(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert Exception.message(error) == "too big: must be at most 10.5"
    end

    test "max for decimal" do
      schema = Zoi.decimal() |> Zoi.max(Decimal.new("10.5"))
      assert {:ok, Decimal.new("9.99")} == Zoi.parse(schema, "9.99")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "12.34")
      assert Exception.message(error) == "too big: must be at most 10.5"
    end

    test "max for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.max(3)
      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3, 4])
      assert Exception.message(error) == "too big: must have at most 3 items"
    end
  end

  describe "lte/2" do
    test "lte for string" do
      schema = Zoi.string() |> Zoi.lte(5)
      assert {:ok, "hi"} == Zoi.parse(schema, "hi")
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello world")
      assert Exception.message(error) == "too big: must have at most 5 characters"
    end

    test "lte for integer" do
      schema = Zoi.integer() |> Zoi.lte(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:ok, 10} == Zoi.parse(schema, 10)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 15)
      assert Exception.message(error) == "too big: must be at most 10"
    end

    test "lte for float" do
      schema = Zoi.float() |> Zoi.lte(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:ok, 10.5} == Zoi.parse(schema, 10.5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert Exception.message(error) == "too big: must be at most 10.5"
    end

    test "lte for decimal" do
      schema = Zoi.decimal() |> Zoi.lte(Decimal.new("10.5"))
      assert {:ok, Decimal.new("9.99")} == Zoi.parse(schema, "9.99")
      assert {:ok, Decimal.new("10.5")} == Zoi.parse(schema, "10.5")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "12.34")
      assert Exception.message(error) == "too big: must be at most 10.5"
    end

    test "lte for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.lte(3)
      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3, 4])
      assert Exception.message(error) == "too big: must have at most 3 items"
    end
  end

  describe "lt/2" do
    test "lt for string" do
      schema = Zoi.string() |> Zoi.lt(5)
      assert {:ok, "hi"} == Zoi.parse(schema, "hi")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello world")
      assert Exception.message(error) == "too big: must have less than 5 characters"
    end

    test "lt for integer" do
      schema = Zoi.integer() |> Zoi.lt(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10)
      assert Exception.message(error) == "too big: must be less than 10"
    end

    test "lt for float" do
      schema = Zoi.float() |> Zoi.lt(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 10.5)
      assert Exception.message(error) == "too big: must be less than 10.5"
    end

    test "lt for decimal" do
      schema = Zoi.decimal() |> Zoi.lt(Decimal.new("10.5"))
      assert {:ok, Decimal.new("9.99")} == Zoi.parse(schema, "9.99")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "10.5")
      assert Exception.message(error) == "too big: must be less than 10.5"
    end

    test "lt for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.lt(3)
      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3])
      assert Exception.message(error) == "too big: must have less than 3 items"
    end
  end

  describe "length/2" do
    test "length for string" do
      schema = Zoi.string() |> Zoi.length(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "invalid length: must have 5 characters"
    end

    test "length for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.length(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2])
      assert Exception.message(error) == "invalid length: must have 3 items"
    end
  end

  describe "regex/2" do
    test "valid regex match" do
      schema = Zoi.string() |> Zoi.regex(~r/^\d+$/)
      assert {:ok, "12345"} == Zoi.parse(schema, "12345")
    end

    test "invalid regex match" do
      schema = Zoi.string() |> Zoi.regex(~r/^\d+$/)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "abc")
      assert Exception.message(error) == "invalid string: must match a pattern ~r/^\\d+$/"
    end

    test "custom message" do
      schema = Zoi.string() |> Zoi.regex(~r/^\d+$/, message: "must be a number")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "abc")
      assert Exception.message(error) == "must be a number"
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
      assert Exception.message(error) == "invalid string: must start with 'prefix_'"
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
      assert Exception.message(error) == "invalid string: must end with '_suffix'"
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

  describe "refine/2" do
    test "valid refinement" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _schema, value ->
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
        |> Zoi.refine(fn _schema, value ->
          if String.length(value) > 3 do
            :ok
          else
            {:error, "must be longer than 3 characters"}
          end
        end)

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "must be longer than 3 characters"
    end

    test "refinement validation when no pattern match" do
      schema = Zoi.string() |> Zoi.refine({Zoi.Refinements, :refine, [[], []]})
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
    end
  end

  describe "transform/2" do
    test "valid transform" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _schema, value -> {:ok, String.upcase(value)} end)

      assert {:ok, "HELLO"} == Zoi.parse(schema, "hello")
    end

    test "invalid transform" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _schema, _value -> {:error, "transform error"} end)

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello")
      assert Exception.message(error) == "transform error"
    end

    test "transform with no pattern match" do
      schema = Zoi.string() |> Zoi.transform({Zoi.Transforms, :transform, [[], []]})
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
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
               0 => ["invalid type: must be an integer"],
               2 => ["invalid type: must be an integer"]
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
                 "user" => %{
                   "profile" => %{"email" => "tt", "numbers" => [1, 2, "not an integer"]}
                 },
                 "invalid_key" => "value"
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
                     "too small: must have at least 4 characters"
                   ],
                   numbers: %{
                     2 => [
                       "invalid type: must be an integer"
                     ]
                   }
                 }
               },
               __errors__: ["unrecognized key: 'invalid_key'"]
             }
    end
  end

  describe "preetify_error/1" do
    test "prettify single error" do
      error = %Zoi.Error{path: [:name], message: "is required"}
      assert "is required, at name\n" == Zoi.prettify_errors([error])
    end

    test "prettify nested errors" do
      error_1 = %Zoi.Error{path: [:user, :name], message: "is required"}
      error_2 = %Zoi.Error{path: [:user, :age], message: "is required"}

      assert "is required, at user.name\nis required, at user.age\n" ==
               Zoi.prettify_errors([error_1, error_2])
    end

    test "prettify errors without path" do
      error = %Zoi.Error{message: "invalid type"}
      assert "invalid type\n" == Zoi.prettify_errors([error])
    end

    test "prettify errors in array" do
      schema = Zoi.array(Zoi.integer())
      assert {:error, errors} = Zoi.parse(schema, ["not an integer", 2, "not an integer"])

      assert "invalid type: must be an integer, at [0]\ninvalid type: must be an integer, at [2]\n" ==
               Zoi.prettify_errors(errors)
    end

    test "prettify empty errors" do
      assert "" == Zoi.prettify_errors([])
    end
  end
end
