defmodule Zoi.InspectTest do
  use ExUnit.Case, async: true
  doctest Zoi.ISO

  test "inspect all types" do
    types = [
      {Zoi.any(), "#Zoi.any<>"},
      {Zoi.array(Zoi.string()), "#Zoi.array<coerce: false, inner: #Zoi.string<coerce: false>>"},
      {Zoi.atom(), "#Zoi.atom<>"},
      {Zoi.boolean(), "#Zoi.boolean<coerce: false>"},
      {Zoi.date(), "#Zoi.date<coerce: false>"},
      {Zoi.datetime(), "#Zoi.date_time<coerce: false>"},
      {Zoi.decimal(), "#Zoi.decimal<coerce: false>"},
      {Zoi.default(Zoi.string(), "hello"), "#Zoi.string<coerce: false, default: \"hello\">"},
      {Zoi.discriminated_union(:type, [
         Zoi.map(%{type: Zoi.literal("cat"), meow: Zoi.string()}),
         Zoi.map(%{type: Zoi.literal("dog"), bark: Zoi.string()})
       ]),
       "#Zoi.discriminated_union<coerce: false, field: \":type\", schemas: [#Zoi.map<coerce: false, strict: false, fields: %{type: #Zoi.literal<required: true, value: \"cat\">, meow: #Zoi.string<required: true, coerce: false>}>, #Zoi.map<coerce: false, strict: false, fields: %{type: #Zoi.literal<required: true, value: \"dog\">, bark: #Zoi.string<required: true, coerce: false>}>]>"},
      {Zoi.enum([:a, :b, :c]), "#Zoi.enum<coerce: false, values: [:a, :b, :c]>"},
      {Zoi.enum(a: "a", b: "b"), "#Zoi.enum<coerce: false, values: [a: \"a\", b: \"b\"]>"},
      {Zoi.float(), "#Zoi.float<coerce: false>"},
      {Zoi.function(), "#Zoi.function<>"},
      {Zoi.function(arity: 2), "#Zoi.function<arity: 2>"},
      {Zoi.pid(), "#Zoi.pid<>"},
      {Zoi.module(), "#Zoi.module<>"},
      {Zoi.reference(), "#Zoi.reference<>"},
      {Zoi.port(), "#Zoi.port<>"},
      {Zoi.macro(), "#Zoi.macro<>"},
      {Zoi.integer(), "#Zoi.integer<coerce: false>"},
      {Zoi.intersection([Zoi.number(), Zoi.float()]),
       "#Zoi.intersection<schemas: [#Zoi.number<coerce: false>, #Zoi.float<coerce: false>]>"},
      {Zoi.keyword(Zoi.string()),
       "#Zoi.keyword<coerce: false, strict: false, fields: #Zoi.string<coerce: false>>"},
      {Zoi.keyword(name: Zoi.string(), age: Zoi.integer()),
       "#Zoi.keyword<coerce: false, strict: false, fields: [name: #Zoi.string<coerce: false>, age: #Zoi.integer<coerce: false>]>"},
      {Zoi.literal("hello"), "#Zoi.literal<value: \"hello\">"},
      {Zoi.map(Zoi.string(), Zoi.integer()),
       "#Zoi.map<key: #Zoi.string<coerce: false>, value: #Zoi.integer<coerce: false>>"},
      {Zoi.map(), "#Zoi.map<key: #Zoi.any<>, value: #Zoi.any<>>"},
      {Zoi.naive_datetime(), "#Zoi.naive_date_time<coerce: false>"},
      {Zoi.null(), "#Zoi.null<>"},
      {Zoi.nullable(Zoi.string()),
       "#Zoi.union<schemas: [#Zoi.null<>, #Zoi.string<coerce: false>]>"},
      {Zoi.nullish(Zoi.string()),
       "#Zoi.union<required: false, schemas: [#Zoi.null<>, #Zoi.string<coerce: false>]>"},
      {Zoi.number(), "#Zoi.number<coerce: false>"},
      {Zoi.map(%{name: Zoi.string()}),
       "#Zoi.map<coerce: false, strict: false, fields: %{name: #Zoi.string<required: true, coerce: false>}>"},
      {Zoi.map(%{name: Zoi.string()}),
       "#Zoi.map<coerce: false, strict: false, fields: %{name: #Zoi.string<required: true, coerce: false>}>"},
      {Zoi.optional(Zoi.string()), "#Zoi.string<required: false, coerce: false>"},
      {Zoi.required(Zoi.string()), "#Zoi.string<required: true, coerce: false>"},
      {Zoi.string(coerce: true), "#Zoi.string<coerce: true>"},
      {Zoi.string_boolean(),
       "#Zoi.string_boolean<case: \"insensitive\", truthy: [\"true\", \"1\", \"yes\", \"on\", \"y\", \"enabled\"], falsy: [\"false\", \"0\", \"no\", \"off\", \"n\", \"disabled\"]>"},
      {Zoi.struct(MyStruct), "#Zoi.struct<coerce: false, strict: false, module: MyStruct>"},
      {Zoi.struct(MyStruct, %{name: Zoi.string()}),
       "#Zoi.struct<coerce: false, strict: false, fields: %{name: #Zoi.string<required: true, coerce: false>}, module: MyStruct>"},
      {Zoi.time(), "#Zoi.time<coerce: false>"},
      {Zoi.tuple({Zoi.string(), Zoi.integer()}),
       "#Zoi.tuple<fields: {#Zoi.string<coerce: false>, #Zoi.integer<coerce: false>}>"},
      {Zoi.union([Zoi.string(), Zoi.integer()]),
       "#Zoi.union<schemas: [#Zoi.string<coerce: false>, #Zoi.integer<coerce: false>]>"},
      {Zoi.lazy(fn -> Zoi.string() end), "#Zoi.lazy<>"},
      {Zoi.ISO.date(), "#Zoi.ISO.date<>"},
      {Zoi.ISO.datetime(), "#Zoi.ISO.date_time<>"},
      {Zoi.ISO.naive_datetime(), "#Zoi.ISO.naive_date_time<>"},
      {Zoi.ISO.time(), "#Zoi.ISO.time<>"},
      {Zoi.codec(Zoi.string(), Zoi.string(),
         decode: fn x -> x end,
         encode: fn x -> x end
       ), "#Zoi.codec<from: #Zoi.string<coerce: false>, to: #Zoi.string<coerce: false>>"}
    ]

    Enum.each(types, fn {type, expected} ->
      assert inspect(type) == expected
    end)
  end

  test "inspect nested types" do
    type =
      Zoi.map(%{
        nest: Zoi.map(%{name: Zoi.string()})
      })

    expected =
      "#Zoi.map<coerce: false, strict: false, fields: %{" <>
        "nest: #Zoi.map<required: true, coerce: false, strict: false, fields: %{name: #Zoi.string<required: true, coerce: false>}>" <>
        "}>"

    assert inspect(type) == expected
  end

  test "inspect type with description metadata" do
    type = Zoi.string(description: "A test string")

    expected = "#Zoi.string<description: \"A test string\", coerce: false>"

    assert inspect(type) == expected
  end

  describe "inspect numeric types with constraints" do
    test "integer with gte/lte" do
      assert inspect(Zoi.integer(gte: 0, lte: 100)) ==
               "#Zoi.integer<coerce: false, gte: 0, lte: 100>"
    end

    test "integer with gt/lt" do
      assert inspect(Zoi.integer(gt: 0, lt: 100)) ==
               "#Zoi.integer<coerce: false, gt: 0, lt: 100>"
    end

    test "float with constraints" do
      assert inspect(Zoi.float(gte: 0.0, lte: 1.0)) ==
               "#Zoi.float<coerce: false, gte: 0.0, lte: 1.0>"
    end

    test "number with constraints" do
      assert inspect(Zoi.number(gte: 10, lte: 100)) ==
               "#Zoi.number<coerce: false, gte: 10, lte: 100>"
    end

    test "decimal with constraints" do
      assert inspect(Zoi.decimal(gte: Decimal.new(0), lte: Decimal.new(100))) ==
               "#Zoi.decimal<coerce: false, gte: Decimal.new(\"0\"), lte: Decimal.new(\"100\")>"
    end
  end

  describe "inspect date/time types with constraints" do
    test "date with gte/lte" do
      assert inspect(Zoi.date(gte: ~D[2020-01-01], lte: ~D[2025-12-31])) ==
               "#Zoi.date<coerce: false, gte: ~D[2020-01-01], lte: ~D[2025-12-31]>"
    end

    test "time with gte/lte" do
      assert inspect(Zoi.time(gte: ~T[09:00:00], lte: ~T[17:00:00])) ==
               "#Zoi.time<coerce: false, gte: ~T[09:00:00], lte: ~T[17:00:00]>"
    end

    test "datetime with gte" do
      assert inspect(Zoi.datetime(gte: ~U[2020-01-01 00:00:00Z])) ==
               "#Zoi.date_time<coerce: false, gte: ~U[2020-01-01 00:00:00Z]>"
    end

    test "naive_datetime with gte" do
      assert inspect(Zoi.naive_datetime(gte: ~N[2020-01-01 00:00:00])) ==
               "#Zoi.naive_date_time<coerce: false, gte: ~N[2020-01-01 00:00:00]>"
    end
  end
end
