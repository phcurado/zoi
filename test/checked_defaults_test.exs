defmodule Zoi.CheckedDefaultsTest do
  use ExUnit.Case, async: true

  defp checked(schema, input, opts \\ []),
    do: Zoi.parse(schema, input, Keyword.put(opts, :parse_defaults, true))

  test "existing defaults still bypass type checks and transforms" do
    assert {:ok, "wrong"} = Zoi.parse(Zoi.integer() |> Zoi.default("wrong"), nil)
    schema = Zoi.integer() |> Zoi.transform(&(&1 + 1)) |> Zoi.default(1)
    assert {:ok, 1} = Zoi.parse(schema, nil)
  end

  test "checked defaults reject the wrong type" do
    assert {:error, [%Zoi.Error{}]} = checked(Zoi.integer() |> Zoi.default("wrong"), nil)
  end

  test "checked defaults enforce refinements" do
    assert {:error, [%Zoi.Error{}]} =
             checked(Zoi.string() |> Zoi.starts_with("ok_") |> Zoi.default("bad"), nil)
  end

  test "default transforms run once" do
    schema = Zoi.integer() |> Zoi.transform(&(&1 + 1)) |> Zoi.default(1)
    assert {:ok, 2} = checked(schema, nil)
    assert {:ok, 6} = checked(schema, 5)
  end

  test "type changing transforms run once" do
    schema = Zoi.integer() |> Zoi.transform(&Integer.to_string/1) |> Zoi.default(1)
    assert {:ok, "1"} = checked(schema, nil)
    assert {:ok, "5"} = checked(schema, 5)
  end

  test "nested defaults report the field path" do
    schema =
      Zoi.map(%{
        outer: Zoi.map(%{inner: Zoi.integer() |> Zoi.default("bad")}) |> Zoi.default(%{})
      })

    assert {:error, [%Zoi.Error{path: [:outer, :inner]}]} = checked(schema, %{})
  end

  test "nested defaults at depth 70 use one parse and one leaf transform" do
    counter = :atomics.new(1, [])

    leaf =
      Zoi.integer()
      |> Zoi.transform(fn n ->
        :atomics.add(counter, 1, 1)
        n + 1
      end)
      |> Zoi.default(1)

    schema =
      Enum.reduce(1..70, leaf, fn _, child -> Zoi.map(%{child: child}) |> Zoi.default(%{}) end)

    expected = Enum.reduce(1..70, 2, fn _, child -> %{child: child} end)
    assert {:ok, ^expected} = checked(schema, nil)
    assert :atomics.get(counter, 1) == 1
  end

  test "nil defaults must satisfy the input type" do
    assert {:error, [%Zoi.Error{}]} = checked(Zoi.integer() |> Zoi.default(nil), nil)
    assert {:ok, nil} = checked(Zoi.integer() |> Zoi.nullable() |> Zoi.default(nil), nil)
  end

  test "optional missing fields stay absent but explicit nil selects the default" do
    schema =
      Zoi.map(%{
        name: Zoi.string() |> Zoi.transform(&(&1 <> "!")) |> Zoi.default("none") |> Zoi.optional()
      })

    assert {:ok, %{}} = checked(schema, %{})
    assert {:ok, %{name: "none!"}} = checked(schema, %{name: nil})
  end

  test "coercion applies to default input" do
    schema = Zoi.integer() |> Zoi.default("10")
    assert {:error, [%Zoi.Error{}]} = checked(schema, nil)
    assert {:ok, 10} = checked(schema, nil, coerce: true)
  end

  test "list element defaults inherit the option" do
    schema = Zoi.list(Zoi.integer() |> Zoi.transform(&(&1 + 1)) |> Zoi.default(1))
    assert {:ok, [2, 3]} = checked(schema, [nil, 2])
  end

  test "required fields without defaults still fail" do
    assert {:error, [%Zoi.Error{}]} = checked(Zoi.map(%{count: Zoi.integer()}), %{})
  end
end
