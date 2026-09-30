defmodule Zoi.ValidateTest do
  use ExUnit.Case, async: true

  test "validation accepts complete object intersections without parsing branches twice" do
    counter = :atomics.new(1, [])

    leaf =
      Zoi.integer()
      |> Zoi.refine(fn _ ->
        :atomics.add(counter, 1, 1)
        :ok
      end)

    schema = Zoi.intersection([Zoi.object(%{a: leaf}), Zoi.object(%{b: leaf})])
    assert :ok = Zoi.validate(schema, %{a: 1, b: 2})
    assert :atomics.get(counter, 1) == 2
    assert {:error, _} = Zoi.validate(schema, %{a: 1})
  end

  test "validation reports a stripped map key inside a list at the enclosing object" do
    schema = Zoi.list(Zoi.object(%{a: Zoi.integer()}))
    assert {:error, [%Zoi.Error{path: [0]}]} = Zoi.validate(schema, [%{a: 1, other: 2}])
  end

  test "validation does not insert nested defaults" do
    schema =
      Zoi.map(%{outer: Zoi.map(%{inner: Zoi.integer() |> Zoi.default(1)}) |> Zoi.default(%{})})

    assert {:error, [%Zoi.Error{path: [:outer], code: :required}]} = Zoi.validate(schema, %{})

    assert {:error, [%Zoi.Error{path: [:outer, :inner], code: :required}]} =
             Zoi.validate(schema, %{outer: %{}})

    assert :ok = Zoi.validate(schema, %{outer: %{inner: 1}})
  end

  test "validation checks explicit nil without replacing it" do
    assert {:error, _} = Zoi.validate(Zoi.integer() |> Zoi.default(1), nil)
    assert :ok = Zoi.validate(Zoi.integer() |> Zoi.nullable() |> Zoi.default(1), nil)
  end

  test "optional fields can stay absent" do
    schema = Zoi.map(%{count: Zoi.integer() |> Zoi.default(1) |> Zoi.optional()})
    assert :ok = Zoi.validate(schema, %{})
    assert {:error, _} = Zoi.validate(schema, %{count: nil})
  end

  test "validation cannot enable coercion" do
    schema = Zoi.integer(coerce: true)
    assert :ok = Zoi.validate(schema, 1)
    assert {:error, _} = Zoi.validate(schema, "1", coerce: true)
    assert {:ok, 1} = Zoi.parse(schema, "1")
  end

  test "transforms do not run during validation" do
    counter = :atomics.new(1, [])

    schema =
      Zoi.integer()
      |> Zoi.transform(fn n ->
        :atomics.add(counter, 1, 1)
        n + 1
      end)

    assert :ok = Zoi.validate(schema, 1)
    assert :atomics.get(counter, 1) == 0
    assert {:ok, 2} = Zoi.parse(schema, 1)
    assert :atomics.get(counter, 1) == 1
  end

  test "refinements run exactly once on stored values" do
    counter = :atomics.new(1, [])

    schema =
      Zoi.integer()
      |> Zoi.refine(fn n ->
        :atomics.add(counter, 1, 1)
        if n > 0, do: :ok, else: {:error, "must be positive"}
      end)

    assert :ok = Zoi.validate(schema, 1)
    assert {:error, [%Zoi.Error{}]} = Zoi.validate(schema, 0)
    assert :atomics.get(counter, 1) == 2
  end

  test "validation rejects a refinement that changes the value" do
    schema = Zoi.integer() |> Zoi.refine(fn n, ctx -> %{ctx | valid?: true, parsed: n + 1} end)
    assert {:error, [%Zoi.Error{code: :custom}]} = Zoi.validate(schema, 1)
    assert {:ok, 2} = Zoi.parse(schema, 1)
  end

  test "validation rejects a type parser that strips a nested key" do
    schema = Zoi.map(%{outer: Zoi.map(%{count: Zoi.integer()})})

    assert {:error, [%Zoi.Error{path: [:outer]}]} =
             Zoi.validate(schema, %{outer: %{count: 1, other: 2}})
  end

  test "validation preserves unknown keys when the schema permits them" do
    schema = Zoi.map(%{count: Zoi.integer()}, unrecognized_keys: :preserve)
    assert :ok = Zoi.validate(schema, %{count: 1, other: 2})
  end

  test "validation options reach union branches and list items" do
    schema = Zoi.list(Zoi.union([Zoi.integer() |> Zoi.default(1), Zoi.string()]))
    assert :ok = Zoi.validate(schema, [1, "yes"])
    assert {:error, _} = Zoi.validate(schema, [nil])
  end

  test "input defaults work for keyword and struct fields" do
    schema = Zoi.keyword(count: Zoi.integer() |> Zoi.default("bad"))
    assert {:error, [%Zoi.Error{path: [:count]}]} = Zoi.parse(schema, [], parse_defaults: true)
    schema = Zoi.struct(URI, %{path: Zoi.string() |> Zoi.default(123)})
    assert {:error, _} = Zoi.parse(schema, %URI{}, parse_defaults: true)
  end

  test "configured empty values take the missing field path" do
    schema = Zoi.map(%{count: Zoi.integer() |> Zoi.default("bad")}, empty_values: [""])

    assert {:error, [%Zoi.Error{path: [:count]}]} =
             Zoi.parse(schema, %{count: ""}, parse_defaults: true)

    assert {:error, _} = Zoi.validate(schema, %{count: ""})
  end

  test "codec validation checks output without decode or encode callbacks" do
    schema =
      Zoi.codec(Zoi.string(), Zoi.integer(),
        decode: fn _ -> flunk("decode ran") end,
        encode: fn _ -> flunk("encode ran") end
      )

    assert :ok = Zoi.validate(schema, 1)
    assert {:error, _} = Zoi.validate(schema, "1")
  end

  test "schema coercion cannot convert a map into a struct during validation" do
    schema = Zoi.struct(URI, nil, coerce: true)
    assert :ok = Zoi.validate(schema, %URI{})
    assert {:error, _} = Zoi.validate(schema, %{})
  end

  test "immutable refinements check default input in one traversal" do
    counter = :atomics.new(1, [])

    schema =
      Zoi.integer()
      |> Zoi.refine(fn n, ctx ->
        :atomics.add(counter, 1, 1)
        %{ctx | valid?: true, parsed: n + 1}
      end)
      |> Zoi.default(1)

    assert {:error, [%Zoi.Error{}]} =
             Zoi.parse(schema, nil, parse_defaults: true, immutable_refinements: true)

    assert :atomics.get(counter, 1) == 1
  end

  test "input empty-value handling cannot remove a stored nullable nil" do
    field = Zoi.integer() |> Zoi.nullable() |> Zoi.default(nil)
    schema = Zoi.map(%{count: field}, empty_values: [nil])
    assert {:ok, state} = Zoi.parse(schema, %{}, parse_defaults: true)
    assert state === %{count: nil}
    assert :ok = Zoi.validate(schema, state)
    assert :ok = Zoi.validate(Zoi.keyword([count: field], empty_values: [nil]), count: nil)
  end
end
