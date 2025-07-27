defmodule ZoiTest do
  use ExUnit.Case

  describe "parse/3" do
    test "string with correct value" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.string(), "hello")
    end

    test "string with incorrect value" do
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(Zoi.string(), 12)
      assert error.message == "invalid string type"
    end

    test "integer with correct value" do
      assert {:ok, 22} == Zoi.parse(Zoi.integer(), 22)
    end

    test "integer with incorrect value" do
      assert {:error, %Zoi.Error{} = error} = Zoi.parse(Zoi.integer(), "12")
      assert error.message == "invalid integer type"
    end

    test "optional" do
      assert {:ok, "hello"} == Zoi.parse(Zoi.optional(Zoi.string()), "hello")
      assert {:ok, nil} == Zoi.parse(Zoi.optional(Zoi.string()), nil)
    end

    test "map with correct value" do
      schema = Zoi.map(%{name: Zoi.string(), age: Zoi.integer()})

      assert {:ok, %{name: "John", age: 30}} ==
               Zoi.parse(schema, %{
                 "name" => "John",
                 "age" => 30
               })
    end
  end
end
