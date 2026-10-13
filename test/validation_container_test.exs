defmodule Zoi.ValidationContainerTest do
  use ExUnit.Case, async: true

  def recursive_default_node do
    Zoi.object(%{
      next: Zoi.lazy({__MODULE__, :recursive_default_node, []}) |> Zoi.default(%{})
    })
  end

  test "dictionary keys and values skip transforms during validation" do
    key = Zoi.string() |> Zoi.transform(fn _ -> flunk("key transform ran") end)
    value = Zoi.integer() |> Zoi.transform(fn _ -> flunk("value transform ran") end)
    assert :ok = Zoi.validate(Zoi.map(key, value), %{"a" => 1})
  end

  test "dictionary values cannot bypass required types through defaults" do
    schema = Zoi.map(Zoi.string(), Zoi.integer() |> Zoi.default(nil))
    assert {:error, [%Zoi.Error{path: ["a"]}]} = Zoi.validate(schema, %{"a" => nil})
    assert :ok = Zoi.validate(schema, %{"a" => 1})
  end

  test "dictionary checked defaults report key and value paths" do
    bad = Zoi.integer() |> Zoi.default("bad")

    assert {:error, [%Zoi.Error{path: ["a"]}]} =
             Zoi.parse(Zoi.map(Zoi.string(), bad), %{"a" => nil}, parse_defaults: true)

    assert {:error, [%Zoi.Error{path: [nil]}]} =
             Zoi.parse(Zoi.map(bad, Zoi.integer()), %{nil => 1}, parse_defaults: true)
  end

  test "dictionary keys and values reject changing refinements" do
    key =
      Zoi.string()
      |> Zoi.refine(fn value, ctx -> %{ctx | valid?: true, parsed: value <> "!"} end)

    value =
      Zoi.integer() |> Zoi.refine(fn value, ctx -> %{ctx | valid?: true, parsed: value + 1} end)

    for schema <- [Zoi.map(key, Zoi.integer()), Zoi.map(Zoi.string(), value)] do
      assert {:error, [%Zoi.Error{path: ["a"]}]} =
               Zoi.parse(schema, %{"a" => 1}, immutable_refinements: true)
    end
  end

  test "dictionary propagation retains legacy global coercion behavior" do
    schema = Zoi.map(Zoi.string(), Zoi.integer())
    assert {:error, _} = Zoi.parse(schema, %{"a" => "1"}, coerce: true)
    coercing = Zoi.map(Zoi.string(), Zoi.integer(coerce: true))
    assert {:ok, %{"a" => 1}} = Zoi.parse(coercing, %{"a" => "1"})
    assert {:error, _} = Zoi.validate(coercing, %{"a" => "1"}, coerce: true)
  end

  test "typed preserved fields receive validation and checked-default options" do
    value = Zoi.integer() |> Zoi.transform(fn _ -> flunk("preserved transform ran") end)

    schema =
      Zoi.object(%{a: Zoi.integer()}, unrecognized_keys: {:preserve, {Zoi.string(), value}})

    assert :ok = Zoi.validate(schema, %{:a => 1, "other" => 2})

    bad = Zoi.integer() |> Zoi.default("bad")
    schema = Zoi.object(%{}, unrecognized_keys: {:preserve, {Zoi.string(), bad}})

    assert {:error, [%Zoi.Error{path: ["other"]}]} =
             Zoi.parse(schema, %{"other" => nil}, parse_defaults: true)
  end

  test "mapped enums validate stored outputs without accepting wire inputs" do
    for schema <- [Zoi.enum(admin: "Admin", user: "User"), Zoi.enum(admin: 1, user: 2)] do
      assert :ok = Zoi.validate(schema, :admin)
      assert :ok = Zoi.validate(schema, :user)
      assert {:error, _} = Zoi.validate(schema, :unknown)
      assert {:error, _} = Zoi.validate(schema, "Admin")
      assert {:error, _} = Zoi.validate(schema, 1)
    end

    schema = Zoi.object(%{role: Zoi.enum(admin: "Admin")})
    assert {:ok, stored} = Zoi.parse(schema, %{role: "Admin"})
    assert :ok = Zoi.validate(schema, stored)
  end

  test "enum validation requires exact stored numeric values" do
    assert :ok = Zoi.validate(Zoi.enum([1]), 1)
    assert {:error, _} = Zoi.validate(Zoi.enum([1]), 1.0)
    assert :ok = Zoi.validate(Zoi.enum([1.0]), 1.0)
    assert {:error, _} = Zoi.validate(Zoi.enum([1.0]), 1)
  end

  test "keyword validation retains stored order and root refinements see it once" do
    stored = [a: 1, y: 2, x: 3]

    schema =
      Zoi.keyword([a: Zoi.integer()], unrecognized_keys: :preserve)
      |> Zoi.refine(fn value ->
        assert value === stored
        send(self(), :keyword_checked)
        :ok
      end)

    assert :ok = Zoi.validate(schema, stored)
    assert_received :keyword_checked
    refute_received :keyword_checked

    schema = Zoi.keyword(a: Zoi.integer(), b: Zoi.integer())
    assert :ok = Zoi.validate(schema, b: 2, a: 1)
  end

  test "keyword validation accepts its preserved parse output without changing parse order" do
    schema = Zoi.keyword([a: Zoi.integer()], unrecognized_keys: :preserve)
    assert {:ok, [a: 1, y: 2, x: 3] = stored} = Zoi.parse(schema, a: 1, x: 3, y: 2)
    assert :ok = Zoi.validate(schema, stored)
  end

  test "keyword order handling does not hide changed or stripped values" do
    schema = Zoi.keyword(value: Zoi.string_boolean())
    assert {:error, _} = Zoi.validate(schema, value: "true")
    schema = Zoi.keyword(a: Zoi.integer())
    assert {:error, _} = Zoi.validate(schema, a: 1, other: 2)
    assert {:error, _} = Zoi.validate(schema, a: 1, a: 1)
  end

  test "recursive defaults return a structured error without unbounded expansion" do
    schema = recursive_default_node()
    assert {:ok, %{next: %{}}} = Zoi.parse(schema, %{})

    assert {:error, [%Zoi.Error{path: [:next, :next], code: :custom}]} =
             Zoi.parse(schema, %{}, parse_defaults: true)
  end

  test "default recursion tracking is local to each branch" do
    leaf = Zoi.integer() |> Zoi.default(1)
    schema = Zoi.object(%{a: leaf, b: leaf})
    assert {:ok, %{a: 1, b: 1}} = Zoi.parse(schema, %{}, parse_defaults: true)
  end

  test "validation retains errors from refinements with partial values" do
    schema = Zoi.integer() |> Zoi.refine(fn _ -> {:error, "invalid stored value", 99} end)
    assert {:error, [%Zoi.Error{message: "invalid stored value"}]} = Zoi.validate(schema, 1)
    assert {:error, _} = Zoi.parse(schema, 1, immutable_refinements: true)
  end

  test "empty partial errors cannot bypass immutable refinements" do
    for callback <- [
          fn n -> {:error, [], n + 1} end,
          fn n, ctx -> %{ctx | valid?: false, parsed: n + 1, errors: []} end
        ] do
      schema = Zoi.integer() |> Zoi.refine(callback)

      assert {:error, [%Zoi.Error{code: :custom}]} =
               Zoi.parse(schema, 1, immutable_refinements: true)
    end
  end
end
