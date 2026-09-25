defmodule Zoi.EmptyWorkTest do
  use ExUnit.Case, async: true

  test "a context with prior errors still fails when it has no effects" do
    ctx =
      Zoi.integer()
      |> Zoi.Context.new(42)
      |> Zoi.Context.add_error("prior error")
      |> Zoi.Context.parse()

    refute ctx.valid?
    assert ctx.parsed == nil
    assert Enum.map(ctx.errors, & &1.message) == ["prior error"]
  end

  test "unconstrained types still run transforms and check input types" do
    for {schema, input} <- [
          {Zoi.string(), "ok"},
          {Zoi.integer(), 42},
          {Zoi.float(), 1.5},
          {Zoi.array(Zoi.any()), [nil, 42]}
        ] do
      schema = Zoi.transform(schema, fn value, ctx -> {value, ctx.input, ctx.path} end)
      assert Zoi.parse(schema, input) == {:ok, {input, input, []}}
      assert {:error, _} = Zoi.parse(schema, self())
    end
  end
end
