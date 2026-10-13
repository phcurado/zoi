defmodule Zoi.AtomEnumCoercionTest do
  use ExUnit.Case, async: true

  test "schema coercion accepts only declared atom names" do
    schema = Zoi.enum([:ready, :done], coerce: true)
    assert {:ok, :ready} = Zoi.parse(schema, "ready")
    assert {:ok, :done} = Zoi.parse(schema, "done")
    assert {:ok, :ready} = Zoi.parse(schema, :ready)

    for input <- ["error", "READY", " ready", "unknown", 1, nil] do
      assert {:error, [%Zoi.Error{code: :invalid_enum_value}]} = Zoi.parse(schema, input)
    end
  end

  test "parse coercion can enable and disable atom-name matching" do
    assert {:ok, :ready} = Zoi.parse(Zoi.enum([:ready]), "ready", coerce: true)
    assert {:error, _} = Zoi.parse(Zoi.enum([:ready]), "ready")
    assert {:error, _} = Zoi.parse(Zoi.enum([:ready], coerce: true), "ready", coerce: false)
  end

  test "unknown input does not create an atom" do
    input = "zoi_unknown_enum_#{System.unique_integer([:positive, :monotonic])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(input) end
    assert {:error, _} = Zoi.parse(Zoi.enum([:ready], coerce: true), input)
    assert_raise ArgumentError, fn -> String.to_existing_atom(input) end
  end

  test "nested errors retain their field and array paths" do
    schema = Zoi.object(%{items: Zoi.array(Zoi.enum([:ready], coerce: true))})
    assert {:ok, %{items: [:ready]}} = Zoi.parse(schema, %{items: ["ready"]})

    assert {:error, [%Zoi.Error{path: [:items, 0], code: :invalid_enum_value}]} =
             Zoi.parse(schema, %{items: ["unknown"]})
  end

  test "mapped enums retain their authored wire values" do
    for coerce? <- [false, true] do
      schema = Zoi.enum([ready: "READY", done: "DONE"], coerce: coerce?)
      assert {:ok, :ready} = Zoi.parse(schema, "READY")
      assert {:error, _} = Zoi.parse(schema, "ready")
    end

    assert {:ok, :ready} = Zoi.parse(Zoi.enum(ready: "ready", done: "done"), "ready")
    assert {:ok, :ready} = Zoi.parse(Zoi.enum([ready: 1], coerce: true), 1)
    assert {:ok, :ready} = Zoi.parse(Zoi.enum([ready: 1], coerce: true), :ready)
    assert {:error, _} = Zoi.parse(Zoi.enum([ready: 1], coerce: true), "ready")
  end

  test "existing matches keep priority over atom-name coercion" do
    assert {:ok, "ready"} = Zoi.parse(Zoi.enum([:ready, "ready"], coerce: true), "ready")
    assert {:ok, 1} = Zoi.parse(Zoi.enum([1, 1.0], coerce: true), 1.0)
  end

  test "mixed enums match atom names in either declaration order" do
    for values <- [[:ready, "done"], ["done", :ready], [:ready, 1], [1, :ready]] do
      assert {:ok, :ready} = Zoi.parse(Zoi.enum(values, coerce: true), "ready")
      assert {:error, _} = Zoi.parse(Zoi.enum(values), "ready")
    end
  end

  test "mixed mapped enums match only symmetric atom entries" do
    for values <- [[:b, a: "x"], [{:a, "x"}, :b]] do
      schema = Zoi.enum(values, coerce: true)
      assert {:ok, :b} = Zoi.parse(schema, "b")
      assert {:ok, :a} = Zoi.parse(schema, "x")
      assert {:error, _} = Zoi.parse(schema, "a")
    end

    schema = Zoi.enum([:z, a: :x], coerce: true)
    assert {:ok, :z} = Zoi.parse(schema, "z")
    assert {:error, _} = Zoi.parse(schema, "a")
    assert {:error, _} = Zoi.parse(schema, "x")
  end

  test "coerce and form preparation enable declared atom-name matching" do
    assert {:ok, :ready} = Zoi.parse(Zoi.coerce(Zoi.enum([:ready])), "ready")
    schema = Zoi.Form.prepare(Zoi.object(%{state: Zoi.enum([:ready])}))
    assert {:ok, %{state: :ready}} = Zoi.parse(schema, %{"state" => "ready"})
  end

  test "a coerced atom enum matches before a later union string branch" do
    schema = Zoi.union([Zoi.enum([:ready]), Zoi.string()])
    assert {:ok, "ready"} = Zoi.parse(schema, "ready")
    assert {:ok, :ready} = Zoi.parse(schema, "ready", coerce: true)
    assert {:ok, "unknown"} = Zoi.parse(schema, "unknown", coerce: true)
  end

  test "boolean, nil, and module atoms use their exact declared names" do
    schema = Zoi.enum([true, false, nil], coerce: true)
    assert {:ok, true} = Zoi.parse(schema, "true")
    assert {:ok, false} = Zoi.parse(schema, "false")
    assert {:ok, nil} = Zoi.parse(schema, "nil")

    module_schema = Zoi.enum([__MODULE__], coerce: true)
    assert {:ok, __MODULE__} = Zoi.parse(module_schema, Atom.to_string(__MODULE__))
    assert {:error, _} = Zoi.parse(module_schema, "Zoi.AtomEnumCoercionTest")
  end

  test "literal coercion is unchanged and enum custom errors are retained" do
    assert {:error, _} = Zoi.parse(Zoi.literal(:ready), "ready", coerce: true)

    assert {:error, [%Zoi.Error{message: "select a declared state"}]} =
             Zoi.parse(Zoi.enum([:ready], coerce: true, error: "select a declared state"), "bad")
  end
end
