defmodule Zoi.StructTest do
  use ExUnit.Case, async: true
  doctest Zoi.Struct

  describe "enforce_keys/1" do
    test "return correct enforce_keys" do
      schema =
        Zoi.struct(__MODULE__, %{
          name: Zoi.string(),
          age: Zoi.integer() |> Zoi.default(0) |> Zoi.optional(),
          email: Zoi.string()
        })

      keys = Zoi.Struct.enforce_keys(schema)

      assert :email in keys
      assert :name in keys
    end
  end

  describe "struct_fields/1" do
    test "return correct struct_fields" do
      schema =
        Zoi.struct(__MODULE__, %{
          name: Zoi.string() |> Zoi.required(),
          age: Zoi.integer() |> Zoi.default(0),
          email: Zoi.string()
        })

      keys = Zoi.Struct.struct_fields(schema)

      assert :name in keys
      assert :email in keys
      assert {:age, 0} in keys
    end
  end
end
