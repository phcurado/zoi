defmodule Zoi.IntersectionOutputTest do
  use ExUnit.Case, async: true

  test "object intersections retain each branch's fields in either order" do
    branches = [Zoi.object(%{a: Zoi.integer()}), Zoi.object(%{b: Zoi.integer()})]

    for schemas <- [branches, Enum.reverse(branches)] do
      assert {:ok, %{a: 1, b: 2}} =
               Zoi.parse(Zoi.intersection(schemas), %{a: 1, b: 2, ignored: true})
    end
  end

  test "nested objects and three branches combine recursively" do
    schema =
      Zoi.intersection([
        Zoi.object(%{nested: Zoi.object(%{a: Zoi.integer()})}),
        Zoi.object(%{nested: Zoi.object(%{b: Zoi.integer()})}),
        Zoi.object(%{c: Zoi.integer()})
      ])

    value = %{nested: %{a: 1, b: 2}, c: 3}
    assert {:ok, ^value} = Zoi.parse(schema, value)
  end

  test "branch defaults survive the combined output" do
    schema =
      Zoi.intersection([
        Zoi.object(%{a: Zoi.integer() |> Zoi.default(1)}),
        Zoi.object(%{b: Zoi.integer() |> Zoi.default(2)})
      ])

    assert {:ok, %{a: 1, b: 2}} = Zoi.parse(schema, %{})
  end

  test "branch refinements and distributed transforms run once per branch" do
    counter = :atomics.new(1, [])

    observe = fn _value ->
      :atomics.add(counter, 1, 1)
      :ok
    end

    schema =
      Zoi.intersection([
        Zoi.object(%{a: Zoi.integer()}) |> Zoi.refine(observe),
        Zoi.object(%{b: Zoi.integer()}) |> Zoi.refine(observe)
      ])
      |> Zoi.transform(fn value ->
        :atomics.add(counter, 1, 1)
        Map.new(value, fn {key, number} -> {key, number + 1} end)
      end)

    assert {:ok, %{a: 2, b: 3}} = Zoi.parse(schema, %{a: 1, b: 2})
    assert :atomics.get(counter, 1) == 4
  end

  test "conflicting nested fields return their path in either branch order" do
    branches = [
      Zoi.object(%{nested: Zoi.object(%{count: Zoi.integer() |> Zoi.default(1)})}),
      Zoi.object(%{nested: Zoi.object(%{count: Zoi.integer() |> Zoi.default(2)})})
    ]

    for schemas <- [branches, Enum.reverse(branches)] do
      assert {:error, [%Zoi.Error{code: :custom, path: [:nested, :count]}]} =
               Zoi.parse(Zoi.intersection(schemas), %{nested: %{}})
    end
  end

  test "overlapping field results require exact equality" do
    schema =
      Zoi.intersection([
        Zoi.object(%{count: Zoi.number() |> Zoi.default(1)}),
        Zoi.object(%{count: Zoi.number() |> Zoi.default(1.0)})
      ])

    assert {:error, [%Zoi.Error{path: [:count]}]} = Zoi.parse(schema, %{})
  end

  test "equal scalar and list fields remain valid" do
    branch = Zoi.object(%{a: Zoi.integer(), list: Zoi.list(Zoi.integer())})
    value = %{a: 1, list: [1, 2]}
    assert {:ok, ^value} = Zoi.parse(Zoi.intersection([branch, branch]), value)
  end

  test "branch errors and strict unknown-key policy are retained" do
    schema =
      Zoi.intersection([
        Zoi.object(%{a: Zoi.integer()}, unrecognized_keys: :error),
        Zoi.object(%{b: Zoi.integer()})
      ])

    assert {:error, _} = Zoi.parse(schema, %{a: 1, b: 2})
    assert {:error, [%Zoi.Error{path: [:a]}]} = Zoi.parse(schema, %{a: "bad"})
  end

  test "custom intersection errors also apply to conflicting results" do
    schema =
      Zoi.intersection(
        [
          Zoi.object(%{count: Zoi.integer() |> Zoi.default(1)}),
          Zoi.object(%{count: Zoi.integer() |> Zoi.default(2)})
        ],
        error: "incompatible intersection"
      )

    assert {:error, [%Zoi.Error{message: "incompatible intersection"}]} = Zoi.parse(schema, %{})
  end

  test "existing scalar coercion still returns the last branch result" do
    assert {:ok, 12} =
             Zoi.parse(Zoi.intersection([Zoi.string(), Zoi.integer(coerce: true)]), "12")
  end

  test "conflict paths include the containing object" do
    schema =
      Zoi.object(%{
        both:
          Zoi.intersection([
            Zoi.object(%{count: Zoi.integer() |> Zoi.default(1)}),
            Zoi.object(%{count: Zoi.integer() |> Zoi.default(2)})
          ])
      })

    assert {:error, [%Zoi.Error{path: [:both, :count]}]} = Zoi.parse(schema, %{both: %{}})
  end

  test "conflicting list and struct fields are not merged" do
    for {left, right} <- [
          {[1], [2]},
          {%URI{path: "/left"}, %URI{path: "/right"}},
          {%{a: 1}, [a: 1]}
        ] do
      schema =
        Zoi.intersection([
          Zoi.object(%{field: Zoi.any() |> Zoi.default(left)}),
          Zoi.object(%{field: Zoi.any() |> Zoi.default(right)})
        ])

      assert {:error, [%Zoi.Error{path: [:field]}]} = Zoi.parse(schema, %{})
    end
  end

  test "failed branches stop before later branch effects" do
    schema =
      Zoi.intersection([
        Zoi.object(%{a: Zoi.integer()}),
        Zoi.object(%{b: Zoi.integer()}) |> Zoi.refine(fn _ -> flunk("later branch ran") end)
      ])

    assert {:error, [%Zoi.Error{path: [:a]}]} = Zoi.parse(schema, %{a: "bad", b: 2})
  end

  test "compatible generated projections are independent of branch order and duplication" do
    for depth <- 0..20 do
      projections = Enum.map([:a, :b, :c], &nest(%{&1 => depth}, depth))
      expected = nest(%{a: depth, b: depth, c: depth}, depth)

      for [first, second, third] <- permutations(projections) do
        schemas = Enum.map([first, second, third, first], &projection/1)
        assert {:ok, ^expected} = Zoi.parse(Zoi.intersection(schemas), :input)
      end
    end
  end

  test "deep conflict paths retain every component and stop before later effects" do
    for depth <- [0, 1, 70, 300] do
      schema =
        Zoi.intersection([
          projection(nest(%{leaf: 1}, depth)),
          projection(nest(%{leaf: 2}, depth)),
          Zoi.any() |> Zoi.transform(fn _ -> flunk("branch after conflict ran") end)
        ])

      expected_path = List.duplicate(:child, depth) ++ [:leaf]
      assert {:error, [%Zoi.Error{path: ^expected_path}]} = Zoi.parse(schema, :input)
    end
  end

  test "numeric map keys retain their exact identities and nil is a real field value" do
    left = %{1 => :integer, :nullable => nil}
    right = %{1.0 => :float, :nullable => nil}
    expected = %{1 => :integer, 1.0 => :float, :nullable => nil}

    for results <- [[left, right], [right, left]] do
      assert {:ok, ^expected} = Zoi.parse(Zoi.intersection(Enum.map(results, &projection/1)), nil)
    end

    assert {:error, [%Zoi.Error{path: [:nullable]}]} =
             Zoi.parse(Zoi.intersection([projection(left), projection(%{nullable: 1})]), nil)
  end

  defp projection(result), do: Zoi.any() |> Zoi.transform(fn _input -> result end)

  defp nest(value, 0), do: value
  defp nest(value, depth), do: nest(%{child: value}, depth - 1)

  defp permutations([a, b, c]),
    do: [[a, b, c], [a, c, b], [b, a, c], [b, c, a], [c, a, b], [c, b, a]]
end
