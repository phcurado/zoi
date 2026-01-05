defmodule Zoi.TypeSpecTest do
  use ExUnit.Case, async: true

  describe "Zoi.type_spec/2" do
    test "all iso typespecs" do
      types = [
        {Zoi.ISO.date(), quote(do: binary())},
        {Zoi.ISO.datetime(), quote(do: binary())},
        {Zoi.ISO.naive_datetime(), quote(do: binary())},
        {Zoi.ISO.time(), quote(do: binary())}
      ]

      Enum.each(types, fn {schema, expected} ->
        assert Zoi.type_spec(schema) == expected
      end)
    end

    test "all main typespecs" do
      types = [
        {Zoi.any(), quote(do: any())},
        {Zoi.array(Zoi.string()), quote(do: [binary()])},
        {Zoi.atom(), quote(do: atom())},
        {Zoi.boolean(), quote(do: boolean())},
        {Zoi.date(), quote(do: Date.t())},
        {Zoi.datetime(), quote(do: DateTime.t())},
        {Zoi.decimal(), quote(do: Decimal.t())},
        {Zoi.default(Zoi.string(), "default"), quote(do: binary())},
        {Zoi.enum(["a", "b", "c"]), quote(do: binary())},
        {Zoi.enum(["a", :b, :c]), quote(do: any())},
        {Zoi.enum([:a, :b, :c]), quote(do: :a | :b | :c)},
        {Zoi.enum([1, 2, 3]), quote(do: 1 | 2 | 3)},
        {Zoi.enum([:a, 2, :c]), quote(do: :a | 2 | :c)},
        {Zoi.enum(red: "Red", green: "Green", blue: "Blue"), quote(do: :red | :green | :blue)},
        {Zoi.enum(one: 1, two: 2, three: 3), quote(do: :one | :two | :three)},
        {Zoi.float(), quote(do: float())},
        {Zoi.function(), quote(do: function())},
        {Zoi.pid(), quote(do: pid())},
        {Zoi.module(), quote(do: module())},
        {Zoi.reference(), quote(do: reference())},
        {Zoi.port(), quote(do: port())},
        {Zoi.macro(), quote(do: Macro.t())},
        {Zoi.integer(), quote(do: integer())},
        {Zoi.intersection([Zoi.string(), Zoi.atom()]), quote(do: binary() | atom())},
        {Zoi.literal(nil), quote(do: nil)},
        {Zoi.literal("hello"), quote(do: "hello")},
        {Zoi.literal(1), quote(do: 1)},
        {Zoi.literal(true), quote(do: true)},
        {Zoi.literal(false), quote(do: false)},
        {Zoi.literal(%{hello: "world"}), quote(do: map())},
        {Zoi.literal(["hello", "world"]), quote(do: list())},
        {Zoi.map(), quote(do: map())},
        {Zoi.map(Zoi.string(), Zoi.integer()), quote(do: %{optional(binary()) => integer()})},
        {Zoi.naive_datetime(), quote(do: NaiveDateTime.t())},
        {Zoi.null(), quote(do: nil)},
        {Zoi.nullable(Zoi.string()), quote(do: nil | binary())},
        {Zoi.nullish(Zoi.integer()), quote(do: nil | integer())},
        {Zoi.number(), quote(do: number())},
        {Zoi.optional(Zoi.string()), quote(do: binary())},
        {Zoi.string(), quote(do: binary())},
        {Zoi.string_boolean(), quote(do: boolean())},
        {Zoi.time(), quote(do: Time.t())},
        {Zoi.tuple({Zoi.string(), Zoi.integer(), Zoi.any()}),
         quote(do: {binary(), integer(), any()})},
        {Zoi.union([Zoi.string(), Zoi.integer(), Zoi.number()]),
         quote(do: binary() | integer() | number())},
        {Zoi.lazy(fn -> Zoi.string() end), quote(do: term())}
      ]

      Enum.each(types, fn {schema, expected} ->
        assert Zoi.type_spec(schema) == expected
      end)
    end

    test "keyword typespec" do
      schema = Zoi.keyword(name: Zoi.string(), age: Zoi.integer())
      assert Zoi.type_spec(schema) == quote(do: [name: binary(), age: integer()])
      schema = Zoi.keyword([])
      assert Zoi.type_spec(schema) == quote(do: keyword())

      schema = Zoi.keyword(Zoi.string())
      assert Zoi.type_spec(schema) == quote(do: [{atom(), binary()}])
    end

    test "object typespec" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.nullish(Zoi.integer()),
          address: Zoi.optional(Zoi.string())
        })

      assert Zoi.type_spec(schema) |> normalize_map_or_struct_ast() ==
               quote(
                 do: %{
                   optional(:address) => binary(),
                   optional(:age) => nil | integer(),
                   required(:name) => binary()
                 }
               )

      schema = Zoi.map(%{})
      assert Zoi.type_spec(schema) == quote(do: %{})
    end

    test "object with string keys typespec should return generic map" do
      schema =
        Zoi.map(%{
          "name" => Zoi.string(),
          "age" => Zoi.integer()
        })

      assert Zoi.type_spec(schema) == quote(do: map())
    end

    test "struct typespec" do
      schema =
        Zoi.struct(User, %{
          name: Zoi.string(),
          age: Zoi.integer()
        })

      left = Zoi.type_spec(schema) |> normalize_map_or_struct_ast()

      right =
        quote(
          do: %User{
            age: integer(),
            name: binary()
          }
        )
        |> normalize_map_or_struct_ast()

      assert left == right
    end

    test "struct typespec without fields" do
      schema = Zoi.struct(User)

      assert Zoi.type_spec(schema) |> normalize_map_or_struct_ast() ==
               quote(do: %User{}) |> normalize_map_or_struct_ast()
    end

    test "extend typespec" do
      schema_1 = Zoi.map(%{age: Zoi.integer()})
      schema_2 = Zoi.map(%{name: Zoi.string()})

      schema = Zoi.extend(schema_1, schema_2)

      assert Zoi.type_spec(schema) |> normalize_map_or_struct_ast() ==
               quote(
                 do: %{
                   required(:age) => integer(),
                   required(:name) => binary()
                 }
               )
    end

    test "custom typespec overrides generated type" do
      schema = Zoi.any(typespec: quote(do: pos_integer()))
      assert Zoi.type_spec(schema) == quote(do: pos_integer())
    end

    test "custom typespec with integer validation" do
      schema = Zoi.integer(gte: 0, typespec: quote(do: non_neg_integer()))

      assert {:ok, 0} = Zoi.parse(schema, 0)
      assert {:ok, 42} = Zoi.parse(schema, 42)
      assert {:error, _} = Zoi.parse(schema, -1)
      assert Zoi.type_spec(schema) == quote(do: non_neg_integer())
    end

    test "custom typespec with function signature" do
      schema = Zoi.function(arity: 1, typespec: quote(do: (String.t() -> boolean())))

      assert {:ok, func} = Zoi.parse(schema, &is_binary/1)
      assert is_function(func, 1)
      assert Zoi.type_spec(schema) == quote(do: (String.t() -> boolean()))
    end

    test "nil typespec uses default generated type" do
      schema = Zoi.string()
      assert Zoi.type_spec(schema) == quote(do: binary())
    end
  end

  defp normalize_map_or_struct_ast(ast) do
    Macro.postwalk(ast, fn
      {:%{}, meta, pairs} when is_list(pairs) ->
        sorted =
          Enum.sort_by(pairs, fn {k, _v} ->
            # Sorting by string so we can compare
            Macro.to_string(k)
          end)

        {:%{}, meta, sorted}

      {:%, meta, [mod, {:%{}, meta2, kv}]} ->
        sorted = Enum.sort_by(kv, fn {k, _} -> Macro.to_string(k) end)
        {:%, meta, [mod, {:%{}, meta2, sorted}]}

        {:%{}, meta, sorted}

      other ->
        other
    end)
  end
end
