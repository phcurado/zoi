defmodule Zoi.ArrayPerformanceTest do
  use ExUnit.Case, async: true

  test "partial results retain indices, valid nil values, and child error order" do
    inner =
      Zoi.any()
      |> Zoi.refine(fn
        :bad -> {:error, [Zoi.Error.new(message: "first"), Zoi.Error.new(message: "second")]}
        _ -> :ok
      end)

    ctx = Zoi.array(inner) |> Zoi.Context.new([nil, :bad, 42, :bad]) |> Zoi.Context.parse()

    refute ctx.valid?
    assert ctx.parsed == %{0 => nil, 2 => 42}

    assert Enum.map(ctx.errors, &{&1.path, &1.message}) ==
             [{[1], "first"}, {[1], "second"}, {[3], "first"}, {[3], "second"}]
  end

  test "callbacks retain input order and paths when a child has an empty error list" do
    inner =
      Zoi.any()
      |> Zoi.refine(fn value, ctx ->
        send(self(), {value, ctx.path})
        if value == :bad, do: {:error, []}, else: :ok
      end)

    assert Zoi.parse(Zoi.array(inner), [nil, :bad, 42]) == {:ok, [nil, :bad, 42]}
    assert_received {nil, [0]}
    assert_received {:bad, [1]}
    assert_received {42, [2]}
  end

  test "array constraints retain the full list as a partial result" do
    schema = Zoi.array(Zoi.integer()) |> Zoi.min(5) |> Zoi.max(1)
    ctx = schema |> Zoi.Context.new([1, 2, 3]) |> Zoi.Context.parse()

    assert ctx.parsed == [1, 2, 3]
    assert Enum.map(ctx.errors, & &1.code) == [:greater_than_or_equal_to, :less_than_or_equal_to]
  end
end
