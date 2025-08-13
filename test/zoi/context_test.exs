defmodule Zoi.ContextTest do
  use ExUnit.Case

  alias Zoi.Context

  describe "Context" do
    test "new/2" do
      schema = Zoi.string()
      input = "test input"
      context = Context.new(schema, input)

      assert context.schema == schema
      assert context.input == input
      assert context.parsed == nil
      assert context.path == []
      assert context.errors == []
    end

    test "add_error/2" do
      context = Context.new(Zoi.string(), "test input")
      error = %Zoi.Error{message: "invalid type"}
      updated_context = Context.add_error(context, error)

      assert updated_context.errors == [error]
    end

    test "add_parsed/2" do
      context = Context.new(Zoi.string(), "test input")
      parsed_input = "parsed input"
      updated_context = Context.add_parsed(context, parsed_input)

      assert updated_context.parsed == parsed_input
    end

    test "add_path/2" do
      schema = Zoi.object(%{name: Zoi.string()})
      context = Context.new(schema, "test input")
      path = [:name]
      updated_context = Context.add_path(context, path)

      assert updated_context.path == path
    end
  end
end
