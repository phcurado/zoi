defmodule Zoi.TypeTest do
  use ExUnit.Case, async: true

  defmodule CustomType do
    use Zoi.Type

    def new(opts \\ []) do
      apply_type(opts)
    end

    defimpl Zoi.Type do
      def parse(_schema, _input, _opts) do
        {:ok, "hello"}
      end
    end
  end

  test "create a custom type" do
    assert %CustomType{} = CustomType.new()
  end
end
