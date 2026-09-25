defmodule Zoi.CollectionPerformanceTest do
  use ExUnit.Case, async: true

  defp multiple_errors do
    Zoi.any()
    |> Zoi.refine(fn _ -> {:error, "first"} end)
    |> Zoi.refine(fn _ -> {:error, "second"} end)
  end

  test "tuple partial results and errors retain their order" do
    schema = Zoi.tuple({Zoi.any(), multiple_errors(), Zoi.integer(), multiple_errors()})
    ctx = schema |> Zoi.Context.new({nil, :bad, 42, :bad}) |> Zoi.Context.parse()

    refute ctx.valid?
    assert ctx.parsed == {nil, 42}

    assert Enum.map(ctx.errors, &{&1.path, &1.message}) ==
             [{[1], "first"}, {[1], "second"}, {[3], "first"}, {[3], "second"}]
  end

  test "keyword parsing retains duplicate keys, empty filtering, and child error order" do
    inner =
      Zoi.any()
      |> Zoi.refine(fn value -> if value == :bad, do: {:error, "first"}, else: :ok end)
      |> Zoi.refine(fn value -> if value == :bad, do: {:error, "second"}, else: :ok end)

    schema = Zoi.keyword(inner, empty_values: [nil])
    input = [item: 1, item: :bad, empty: nil, item: 2, other: :bad]
    ctx = schema |> Zoi.Context.new(input) |> Zoi.Context.parse()

    refute ctx.valid?
    assert ctx.parsed == [item: 1, item: 2]

    assert Enum.map(ctx.errors, &{&1.path, &1.message}) ==
             [{[:item], "first"}, {[:item], "second"}, {[:other], "first"}, {[:other], "second"}]
  end

  test "tuple callbacks run in field order" do
    inner =
      Zoi.any()
      |> Zoi.transform(fn value ->
        send(self(), value)
        value
      end)

    schema = Zoi.tuple({inner, inner, inner})
    assert Zoi.parse(schema, {:one, :two, :three}) == {:ok, {:one, :two, :three}}

    for expected <- [:one, :two, :three] do
      assert_receive actual
      assert actual == expected
    end
  end
end
