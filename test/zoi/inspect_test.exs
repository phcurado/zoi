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
      {Zoi.enum([:a, :b, :c]), "#Zoi.enum<values: [:a, :b, :c]>"},
      {Zoi.enum(a: "a", b: "b"), "#Zoi.enum<values: [a: \"a\", b: \"b\"]>"},
      {Zoi.float(), "#Zoi.float<coerce: false>"},
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
      {Zoi.object(%{name: Zoi.string()}),
       "#Zoi.object<coerce: false, strict: false, fields: %{name: #Zoi.string<required: true, coerce: false>}>"},
      {Zoi.optional(Zoi.string()), "#Zoi.string<required: false, coerce: false>"},
      {Zoi.required(Zoi.string()), "#Zoi.string<required: true, coerce: false>"},
      {Zoi.string(coerce: true), "#Zoi.string<coerce: true>"},
      {Zoi.string_boolean(),
       "#Zoi.string_boolean<case: \"insensitive\", truthy: [\"true\", \"1\", \"yes\", \"on\", \"y\", \"enabled\"], falsy: [\"false\", \"0\", \"no\", \"off\", \"n\", \"disabled\"]>"},
      {Zoi.struct(MyStruct, %{name: Zoi.string()}),
       "#Zoi.struct<coerce: false, strict: false, fields: %{name: #Zoi.string<required: true, coerce: false>}, module: MyStruct>"},
      {Zoi.time(), "#Zoi.time<coerce: false>"},
      {Zoi.tuple({Zoi.string(), Zoi.integer()}),
       "#Zoi.tuple<fields: {#Zoi.string<coerce: false>, #Zoi.integer<coerce: false>}>"},
      {Zoi.union([Zoi.string(), Zoi.integer()]),
       "#Zoi.union<schemas: [#Zoi.string<coerce: false>, #Zoi.integer<coerce: false>]>"},
      {Zoi.ISO.date(), "#Zoi.ISO.date<>"},
      {Zoi.ISO.datetime(), "#Zoi.ISO.date_time<>"},
      {Zoi.ISO.naive_datetime(), "#Zoi.ISO.naive_date_time<>"},
      {Zoi.ISO.time(), "#Zoi.ISO.time<>"}
    ]

    Enum.each(types, fn {type, expected} ->
      assert inspect(type) == expected
    end)
  end

  test "inspect nested types" do
    type =
      Zoi.object(%{
        nest: Zoi.object(%{name: Zoi.string()})
      })

    expected =
      "#Zoi.object<coerce: false, strict: false, fields: %{" <>
        "nest: #Zoi.object<required: true, coerce: false, strict: false, fields: %{name: #Zoi.string<required: true, coerce: false>}>" <>
        "}>"

    assert inspect(type) == expected
  end

  test "inspect type with description metadata" do
    type = Zoi.string(description: "A test string")

    expected = "#Zoi.string<description: \"A test string\", coerce: false>"

    assert inspect(type) == expected
  end
end
