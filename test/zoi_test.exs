defmodule ZoiTest do
  use ExUnit.Case

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
      assert_raise Zoi.Error, "default error: invalid integer type", fn ->
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
  end

  describe "length/2" do
    test "length for string" do
      schema = Zoi.string() |> Zoi.length(5)
      assert {:ok, "hello"} == Zoi.parse(schema, "hello")
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(schema, "hi")
      assert Exception.message(error) == "length must be 5"
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
end
