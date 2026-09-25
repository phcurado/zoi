defmodule Zoi.KeyValuePerformanceTest do
  use ExUnit.Case, async: true

  test "errors retain field order and refinement order" do
    refined =
      Zoi.string()
      |> Zoi.refine(fn _ -> {:error, "first refinement"} end)
      |> Zoi.refine(fn _ -> {:error, "second refinement"} end)

    schema = Zoi.object(first: Zoi.integer(), second: refined, third: Zoi.integer())
    assert {:error, errors} = Zoi.parse(schema, %{first: "bad", second: "value"})
    assert Enum.map(errors, & &1.path) == [[:first], [:second], [:second], [:third]]

    assert Enum.map(Enum.slice(errors, 1, 2), & &1.message) == [
             "first refinement",
             "second refinement"
           ]
  end

  test "partial arrays retain indexes and successful sibling fields" do
    schema =
      Zoi.object(
        good: Zoi.integer(),
        items: Zoi.array(Zoi.integer() |> Zoi.min(1)),
        missing: Zoi.string()
      )

    ctx = Zoi.Context.new(schema, %{good: 0, items: [-1, 2, "bad"]}) |> Zoi.Context.parse()
    refute ctx.valid?
    assert ctx.parsed == %{good: 0, items: %{1 => 2}}
    assert Enum.map(ctx.errors, & &1.path) == [[:items, 0], [:items, 2], [:missing]]
  end

  test "many missing fields retain schema order" do
    fields = for i <- 1..1000, do: {"field_#{i}", Zoi.integer()}
    assert {:error, errors} = Zoi.parse(Zoi.object(fields), %{})
    assert Enum.map(errors, & &1.path) == Enum.map(fields, fn {key, _} -> [key] end)
  end

  test "strip does not change input key collision behavior" do
    schema = Zoi.object([name: Zoi.string()], coerce: true)
    input = %{"name" => "string", name: "atom", extra: 42}
    # Map iteration places atom keys before string keys. The last normalized value wins.
    assert Zoi.parse(schema, input) == {:ok, %{name: "string"}}
    keyword = Zoi.keyword([name: Zoi.string()], coerce: true)
    assert Zoi.parse(keyword, name: "first", name: "last", extra: 42) == {:ok, [name: "last"]}
  end
end
