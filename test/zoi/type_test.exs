defmodule Zoi.TypeTest do
  use ExUnit.Case, async: true

  defmodule CustomType do
    use Zoi.Type.Def

    def new(opts \\ []) do
      apply_type(opts)
    end

    defimpl Zoi.Type do
      def parse(_schema, _input, _opts) do
        {:ok, "hello"}
      end
    end

    defimpl Zoi.TypeSpec do
      def spec(_schema, _opts) do
        quote(do: binary())
      end
    end
  end

  test "create a custom type" do
    assert %CustomType{} = CustomType.new()
  end

  test "parse with custom type" do
    assert {:ok, "hello"} = Zoi.parse(CustomType.new(), 123)
  end

  test "type_spec with custom type" do
    schema = CustomType.new()
    assert Zoi.type_spec(schema) == quote(do: binary())
  end

  test "type_spec fallback for unimplemented type" do
    assert_raise ArgumentError, fn ->
      Zoi.type_spec(:unknown_schema)
    end
  end
end
