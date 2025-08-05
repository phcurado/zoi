defmodule ZoiTest do
  use ExUnit.Case

  describe "parse/3" do
    test "string with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.string(), "hello")
    end

    test "string with incorrect value" do
      wrong_values = [12, nil, 12.34, :atom]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.string(), value)
        assert Exception.message(error) == "invalid string type"
      end
    end
  end

  describe "string/2" do
    test "string with coercion" do
      assert {:ok, "123"} == Zoi.parse(Zoi.string(coerce: false), 123, coerce: true)
      assert {:ok, "true"} == Zoi.parse(Zoi.string(), true, coerce: true)
      assert {:ok, "12.34"} == Zoi.parse(Zoi.string(), 12.34, coerce: true)
    end

    test "string with incorrect value" do
      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(Zoi.string(), :not_a_string)

      assert Exception.message(error) == "invalid string type"
    end
  end

  describe "integer/2" do
    test "integer with correct value" do
      assert {:ok, 22} == Zoi.parse(Zoi.integer(), 22)
    end

    test "integer with incorrect value" do
      wrong_values = ["12", nil, 12.34, :atom, "not an integer"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.integer(), value)
        assert Exception.message(error) == "invalid integer type"
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

      assert Exception.message(error) == "invalid integer type"
    end
  end

  describe "float/2" do
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
        assert Exception.message(error) == "invalid float type"
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

      assert Exception.message(error) == "invalid float type"
    end
  end

  describe "number/2" do
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
        # For now, returns float error since it's the last element of the union type.
        # Future to add custom error messages per type.
        assert Exception.message(error) == "invalid float type"
      end
    end
  end

  describe "boolean/2" do
    test "boolean with correct values" do
      assert {:ok, true} == Zoi.parse(Zoi.boolean(), true)
      assert {:ok, false} == Zoi.parse(Zoi.boolean(), false)
    end

    test "boolean with incorrect value" do
      wrong_values = ["12", nil, 12.34, :atom, "true"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.boolean(), value)
        assert Exception.message(error) == "invalid boolean type"
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
        assert Exception.message(error) == "invalid boolean type"
      end
    end
  end

  describe "optional/2" do
    test "optional with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.optional(Zoi.string()), "hello")
    end

    test "optional with nil value" do
      assert {:ok, nil} == Zoi.parse(Zoi.optional(Zoi.string()), nil)
    end

    test "optional with incorrect type" do
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.optional(Zoi.string()), 123)
      assert Exception.message(error) == "invalid string type"
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
                   "Invalid default value: \"10\". Reason: invalid integer type",
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
      assert Exception.message(error) == "invalid integer type"
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
      assert Exception.message(error) == "invalid integer type"

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 3)
      assert Exception.message(error) == "minimum value is 5"
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
      assert Exception.message(error) == "invalid integer type"
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

      assert Exception.message(error) == "invalid integer type"
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

      assert {:ok, %{name: "John", age: nil}} ==
               Zoi.parse(schema, %{
                 "name" => "John",
                 "age" => nil
               })

      assert {:ok, %{name: "John"}} ==
               Zoi.parse(schema, %{
                 "name" => "John"
               })
    end

    test "object with non-map input" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not a map")
      assert Exception.message(error) == "invalid object type"
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

  describe "array/2" do
    test "array with correct values" do
      schema = Zoi.array(Zoi.integer())

      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
    end

    test "array with incorrect value" do
      schema = Zoi.array(Zoi.integer())

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, "not an integer", 3])
      assert Exception.message(error) == "invalid integer type"
      assert error.path == [1]
    end

    test "array with empty array" do
      schema = Zoi.array(Zoi.string())

      assert {:ok, []} == Zoi.parse(schema, [])
    end

    test "array with non-array input" do
      schema = Zoi.array(Zoi.string())

      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "not an array")
      assert Exception.message(error) == "invalid array type"
    end

    test "array with nested arrays" do
      schema = Zoi.array(Zoi.array(Zoi.integer()))

      assert {:ok, [[1, 2], [3, 4]]} == Zoi.parse(schema, [[1, 2], [3, 4]])
    end

    test "array with nested arrays and incorrect value" do
      schema = Zoi.array(Zoi.array(Zoi.integer()))

      assert {:error, [%Zoi.Error{} = error]} =
               Zoi.parse(schema, [[1, 2], ["not an integer", 4]])

      assert Exception.message(error) == "invalid integer type"
      assert error.path == [0, 1]
    end

    test "array with optional elements" do
      schema = Zoi.array(Zoi.optional(Zoi.string()))

      assert {:ok, ["hello", nil, "world"]} ==
               Zoi.parse(schema, ["hello", nil, "world"])

      assert {:ok, [nil]} == Zoi.parse(schema, [nil])
      assert {:ok, []} == Zoi.parse(schema, [])
    end

    test "array with deeply nested arrays" do
      schema = Zoi.array(Zoi.array(Zoi.array(Zoi.integer())))

      assert {:ok, [[[1], [2]], [[3], [4]]]} ==
               Zoi.parse(schema, [[[1], [2]], [[3], [4]]])

      assert {:error, [%Zoi.Error{} = error_1, %Zoi.Error{} = error_2]} =
               Zoi.parse(schema, [[[1], ["not an integer"]], [[3], [4, "not an integer"]]])

      assert Exception.message(error_1) == "invalid integer type"
      assert error_1.path == [0, 1, 0]

      assert Exception.message(error_2) == "invalid integer type"
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
      assert Exception.message(error) == "invalid enum value"
    end

    test "enum parse with incorrect type" do
      schema = Zoi.enum([:apple, :banana, :cherry])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "banana")
      assert Exception.message(error) == "invalid enum value"
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

  describe "min/2" do
    test "min for string" do
      schema = Zoi.string() |> Zoi.min(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "minimum length is 5"
    end

    test "min for integer" do
      schema = Zoi.integer() |> Zoi.min(10)
      assert {:ok, 15} == Zoi.parse(schema, 15)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 5)
      assert Exception.message(error) == "minimum value is 10"
    end

    test "min for float" do
      schema = Zoi.float() |> Zoi.min(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 9.99)
      assert Exception.message(error) == "minimum value is 10.5"
    end

    test "min for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.min(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2])
      assert Exception.message(error) == "minimum array length is 3"
    end
  end

  describe "max/2" do
    test "max for string" do
      schema = Zoi.string() |> Zoi.max(5)
      assert {:ok, "hi"} == Zoi.parse(schema, "hi")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello world")
      assert Exception.message(error) == "maximum length is 5"
    end

    test "max for integer" do
      schema = Zoi.integer() |> Zoi.max(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 15)
      assert Exception.message(error) == "maximum value is 10"
    end

    test "max for float" do
      schema = Zoi.float() |> Zoi.max(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, 12.34)
      assert Exception.message(error) == "maximum value is 10.5"
    end

    test "max for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.max(3)
      assert {:ok, [1, 2]} == Zoi.parse(schema, [1, 2])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2, 3, 4])
      assert Exception.message(error) == "maximum length is 3"
    end
  end

  describe "length/2" do
    test "length for string" do
      schema = Zoi.string() |> Zoi.length(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "length must be 5"
    end

    test "length for array" do
      schema = Zoi.array(Zoi.integer()) |> Zoi.length(3)
      assert {:ok, [1, 2, 3]} == Zoi.parse(schema, [1, 2, 3])
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, [1, 2])
      assert Exception.message(error) == "length must be 3"
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
      assert Exception.message(error) == "regex does not match"
    end
  end

  describe "email/1" do
    test "valid email" do
      schema = Zoi.string() |> Zoi.email()
      assert {:ok, "test@test.com"} == Zoi.parse(schema, "test@test.com")
    end

    test "invalid email" do
      schema = Zoi.string() |> Zoi.email()
      assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid-email")
      assert Exception.message(error) == "invalid email format"
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
      assert Exception.message(error) == "must start with 'prefix_'"
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
      assert Exception.message(error) == "must end with '_suffix'"
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
      assert %{name: [error]} == Zoi.treefy_errors([error])
    end

    test "treefy nested errors" do
      error_1 = %Zoi.Error{path: [:user, :name], message: "is required"}
      error_2 = %Zoi.Error{path: [:user, :age], message: "is required"}

      assert %{user: %{name: [error_1], age: [error_2]}} == Zoi.treefy_errors([error_1, error_2])
    end

    test "treefy errors without path" do
      error = %Zoi.Error{message: "invalid type"}
      # No path means it cannot be treefied
      assert %{} == Zoi.treefy_errors([error])
    end

    test "treefy empty errors" do
      assert %{} == Zoi.treefy_errors([])
    end

    test "object with deeply nested object" do
      schema =
        Zoi.object(%{
          user:
            Zoi.object(%{
              profile:
                Zoi.object(%{
                  email: Zoi.string() |> Zoi.min(4) |> Zoi.email(),
                  age: Zoi.integer(),
                  numbers: Zoi.array(Zoi.integer())
                }),
              active: Zoi.boolean()
            })
        })

      assert {:error, errors} =
               Zoi.parse(schema, %{
                 "user" => %{
                   "profile" => %{"email" => "tt", "numbers" => [1, 2, "not an integer"]}
                 },
                 "invalid_key" => "value"
               })

      assert Zoi.treefy_errors(errors) == %{
               user: %{
                 active: [%Zoi.Error{message: "is required", path: [:user, :active]}],
                 profile: %{
                   age: [
                     %Zoi.Error{
                       message: "is required",
                       path: [:user, :profile, :age]
                     }
                   ],
                   email: [
                     %Zoi.Error{
                       message: "minimum length is 4",
                       path: [:user, :profile, :email]
                     },
                     %Zoi.Error{
                       message: "invalid email format",
                       path: [:user, :profile, :email]
                     }
                   ],
                   numbers: %{
                     2 => [
                       %Zoi.Error{
                         message: "invalid integer type",
                         path: [:user, :profile, :numbers, 2]
                       }
                     ]
                   }
                 }
               }
             }
    end
  end
end
