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
  end
end
