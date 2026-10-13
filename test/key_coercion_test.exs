defmodule Zoi.KeyCoercionTest do
  use ExUnit.Case, async: true

  test "coerced objects reject both forms of a declared key, even with equal values" do
    for key <- [:query, "query"], policy <- [:strip, :preserve, :error], value <- [1, 2] do
      schema = Zoi.object(%{key => Zoi.integer()}, coerce: true, unrecognized_keys: policy)

      assert {:error, [%Zoi.Error{code: :key_collision, path: [^key]}]} =
               Zoi.parse(schema, %{:query => 1, "query" => value})
    end
  end

  test "collision paths include nested objects and array positions" do
    schema =
      Zoi.object(%{
        items: Zoi.array(Zoi.object(%{query: Zoi.integer()}, coerce: true))
      })

    assert {:error, [%Zoi.Error{code: :key_collision, path: [:items, 0, :query]}]} =
             Zoi.parse(schema, %{items: [%{:query => 1, "query" => 2}]})
  end

  test "coercion preserves declared key types without coercing scalar values" do
    for key <- [:query, "query"] do
      schema = Zoi.object(%{key => Zoi.integer()}, coerce: true)
      assert {:ok, %{^key => 1}} = Zoi.parse(schema, %{"query" => 1})
      assert {:error, [%Zoi.Error{code: :invalid_type}]} = Zoi.parse(schema, %{"query" => "1"})
    end
  end

  test "unknown aliases retain the authored unknown-key policy" do
    input = %{:query => 1, :extra => 2, "extra" => 3}

    assert {:ok, ^input} =
             Zoi.parse(
               Zoi.object(%{query: Zoi.integer()}, coerce: true, unrecognized_keys: :preserve),
               input
             )

    assert {:ok, %{query: 1}} =
             Zoi.parse(Zoi.object(%{query: Zoi.integer()}, coerce: true), input)
  end

  test "objects without coercion retain distinct atom and string keys" do
    schema = Zoi.object(%{:query => Zoi.integer(), "query" => Zoi.string()})
    input = %{:query => 1, "query" => "text"}
    assert {:ok, ^input} = Zoi.parse(schema, input)
  end

  test "global coercion rejects declared key collisions" do
    schema = Zoi.object(%{query: Zoi.integer()})

    assert {:error, [%Zoi.Error{code: :key_collision, path: [:query]}]} =
             Zoi.parse(schema, %{:query => 1, "query" => 2}, coerce: true)
  end

  test "discriminator aliases fail before any branch effects" do
    schema =
      Zoi.discriminated_union(
        :kind,
        for kind <- ["cat", "dog"] do
          Zoi.object(%{kind: Zoi.literal(kind)}, coerce: true)
          |> Zoi.refine(fn _ -> flunk("ambiguous discriminator selected a branch") end)
        end,
        coerce: true
      )

    assert {:error, [%Zoi.Error{code: :key_collision, path: [:kind]}]} =
             Zoi.parse(schema, %{:kind => "cat", "kind" => "dog"})
  end

  test "global coercion checks discriminator collisions before selecting a branch" do
    branches =
      for kind <- ["cat", "dog"] do
        Zoi.object(%{kind: Zoi.literal(kind)})
        |> Zoi.refine(fn _ -> flunk("ambiguous discriminator selected a branch") end)
      end

    schema = Zoi.discriminated_union(:kind, branches)

    assert {:error, [%Zoi.Error{code: :key_collision, path: [:kind]}]} =
             Zoi.parse(schema, %{:kind => "cat", "kind" => "cat"}, coerce: true)
  end

  test "a colliding field is not parsed and other field errors keep their order" do
    query = Zoi.string() |> Zoi.refine(fn _ -> flunk("colliding field was parsed") end)
    schema = Zoi.object([query: query, count: Zoi.integer()], coerce: true)

    assert {:error,
            [
              %Zoi.Error{code: :key_collision, path: [:query]},
              %Zoi.Error{code: :invalid_type, path: [:count]}
            ]} = Zoi.parse(schema, %{:query => "a", "query" => "b", :count => "bad"})
  end

  test "parse coercion can disable key normalization" do
    schema = Zoi.object(%{:query => Zoi.integer(), "query" => Zoi.string()}, coerce: true)
    input = %{:query => 1, "query" => "text"}
    assert {:ok, ^input} = Zoi.parse(schema, input, coerce: false)
  end
end
