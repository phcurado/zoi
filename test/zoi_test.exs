defmodule ZoiTest do
  use ExUnit.Case

  describe "Zoi.Error" do
    test "exception/1" do
      assert %Zoi.Error{issues: [], message: "An error occurred"} =
               Zoi.Error.exception(message: "An error occurred")
    end

    test "add_error/2" do
      error = %Zoi.Error{issues: ["invalid type"]}
      updated_error = Zoi.Error.add_error(error, "additional issue")

      assert updated_error.issues == ["additional issue", "invalid type"]
    end
  end

  describe "parse/3" do
    test "string with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.string(), "hello")
    end

    test "string with incorrect value" do
      wrong_values = [12, nil, 12.34, :atom]

      for value <- wrong_values do
        assert {:error, %Zoi.Error{} = error} = Zoi.parse(Zoi.string(), value)
        assert Exception.message(error) == "invalid string type"
        assert error.issues == ["invalid string type"]
      end
    end

    test "string with coercion" do
      assert {:ok, "123"} == Zoi.parse(Zoi.string(coerce: false), 123, coerce: true)
      assert {:ok, "true"} == Zoi.parse(Zoi.string(), true, coerce: true)
      assert {:ok, "12.34"} == Zoi.parse(Zoi.string(), 12.34, coerce: true)
    end

    test "integer with correct value" do
      assert {:ok, 22} == Zoi.parse(Zoi.integer(), 22)
    end

    test "integer with incorrect value" do
      wrong_values = ["12", nil, 12.34, :atom, "not an integer"]

      for value <- wrong_values do
        assert {:error, %Zoi.Error{} = error} = Zoi.parse(Zoi.integer(), value)
        assert Exception.message(error) == "invalid integer type"
        assert error.issues == ["invalid integer type"]
      end
    end

    test "integer with coercion" do
      assert {:ok, 123} == Zoi.parse(Zoi.integer(coerce: false), "123", coerce: true)
      assert {:ok, 0} == Zoi.parse(Zoi.integer(), "0", coerce: true)
      assert {:ok, -1} == Zoi.parse(Zoi.integer(), "-1", coerce: true)
    end

    test "integer with coercion but incorrect value" do
      assert {:error, %Zoi.Error{} = error} =
               Zoi.parse(Zoi.integer(), "not_integer", coerce: true)

      assert Exception.message(error) == "invalid integer type"
      assert error.issues == ["invalid integer type"]
    end

    test "float with correct value" do
      assert {:ok, 12.34} == Zoi.parse(Zoi.float(), 12.34)
    end

    test "float with incorrect value" do
      wrong_values = ["12", nil, 12, :atom, "not a float"]

      for value <- wrong_values do
        assert {:error, %Zoi.Error{} = error} = Zoi.parse(Zoi.float(), value)
        assert Exception.message(error) == "invalid float type"
        assert error.issues == ["invalid float type"]
      end
    end

    test "float with coercion" do
      assert {:ok, 12.34} == Zoi.parse(Zoi.float(coerce: false), "12.34", coerce: true)
      assert {:ok, 0.0} == Zoi.parse(Zoi.float(), "0", coerce: true)
      assert {:ok, -1.0} == Zoi.parse(Zoi.float(), "-1", coerce: true)
    end

    test "float with coercion but incorrect value" do
      assert {:error, %Zoi.Error{} = error} =
               Zoi.parse(Zoi.float(), "not_float", coerce: true)

      assert Exception.message(error) == "invalid float type"
      assert error.issues == ["invalid float type"]
    end

    test "boolean with correct values" do
      assert {:ok, true} == Zoi.parse(Zoi.boolean(), true)
      assert {:ok, false} == Zoi.parse(Zoi.boolean(), false)
    end

    test "boolean with incorrect value" do
      wrong_values = ["12", nil, 12.34, :atom, "true"]

      for value <- wrong_values do
        assert {:error, %Zoi.Error{} = error} = Zoi.parse(Zoi.boolean(), value)
        assert Exception.message(error) == "invalid boolean type"
        assert error.issues == ["invalid boolean type"]
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
        assert {:error, %Zoi.Error{} = error} = Zoi.parse(Zoi.boolean(), value, coerce: true)
        assert Exception.message(error) == "invalid boolean type"
        assert error.issues == ["invalid boolean type"]
      end
    end

    test "optional" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.optional(Zoi.string()), "hello")
      assert {:ok, nil} == Zoi.parse(Zoi.optional(Zoi.string()), nil)
    end

    test "default" do
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

      assert {:error, %Zoi.Error{} = error} =
               Zoi.parse(schema, %{
                 "name" => "John"
               })

      assert error.issues == %{age: %Zoi.Error{issues: ["is required"]}}
    end

    test "object with incorrect values" do
      schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:error, %Zoi.Error{} = error} =
               Zoi.parse(schema, %{
                 "name" => "John",
                 "age" => "not an integer"
               })

      assert error.issues == %{age: %Zoi.Error{issues: ["invalid integer type"]}}
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

      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "not a map")
      assert Exception.message(error) == "invalid object type"
      assert error.issues == ["invalid object type"]
    end

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
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, :orange)
      assert Exception.message(error) == "invalid enum value"
      assert error.issues == ["invalid enum value"]
    end

    test "enum parse with incorrect type" do
      schema = Zoi.enum([:apple, :banana, :cherry])
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "banana")
      assert Exception.message(error) == "invalid enum value"
      assert error.issues == ["invalid enum value"]
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
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "minimum length is 5"
    end

    test "min for integer" do
      schema = Zoi.integer() |> Zoi.min(10)
      assert {:ok, 15} == Zoi.parse(schema, 15)
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, 5)
      assert Exception.message(error) == "minimum value is 10"
    end

    test "min for float" do
      schema = Zoi.float() |> Zoi.min(10.5)
      assert {:ok, 12.34} == Zoi.parse(schema, 12.34)
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, 9.99)
      assert Exception.message(error) == "minimum value is 10.5"
    end
  end

  describe "max/2" do
    test "max for string" do
      schema = Zoi.string() |> Zoi.max(5)
      assert {:ok, "hi"} == Zoi.parse(schema, "hi")
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "hello world")
      assert Exception.message(error) == "maximum length is 5"
    end

    test "max for integer" do
      schema = Zoi.integer() |> Zoi.max(10)
      assert {:ok, 5} == Zoi.parse(schema, 5)
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, 15)
      assert Exception.message(error) == "maximum value is 10"
    end

    test "max for float" do
      schema = Zoi.float() |> Zoi.max(10.5)
      assert {:ok, 9.99} == Zoi.parse(schema, 9.99)
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, 12.34)
      assert Exception.message(error) == "maximum value is 10.5"
    end
  end

  describe "length/2" do
    test "length for string" do
      schema = Zoi.string() |> Zoi.length(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "length must be 5"
    end
  end

  describe "regex/2" do
    test "valid regex match" do
      schema = Zoi.string() |> Zoi.regex(~r/^\d+$/)
      assert {:ok, "12345"} == Zoi.parse(schema, "12345")
    end

    test "invalid regex match" do
      schema = Zoi.string() |> Zoi.regex(~r/^\d+$/)
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "abc")
      assert Exception.message(error) == "regex does not match"
      assert error.issues == ["regex does not match"]
    end
  end

  describe "email/1" do
    test "valid email" do
      schema = Zoi.string() |> Zoi.email()
      assert {:ok, "test@test.com"} == Zoi.parse(schema, "test@test.com")
    end

    test "invalid email" do
      schema = Zoi.string() |> Zoi.email()
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "invalid-email")
      assert Exception.message(error) == "invalid email format"
      assert error.issues == ["invalid email format"]
    end
  end

  describe "starts_with/2" do
    test "valid prefix" do
      schema = Zoi.string() |> Zoi.starts_with("prefix_")
      assert {:ok, "prefix_value"} == Zoi.parse(schema, "prefix_value")
    end

    test "invalid prefix" do
      schema = Zoi.string() |> Zoi.starts_with("prefix_")
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "value")
      assert Exception.message(error) == "must start with 'prefix_'"
      assert error.issues == ["must start with 'prefix_'"]
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
end
