defmodule Zoi.DocsTest do
  use ExUnit.Case, async: true

  @schema Zoi.keyword(
            type: Zoi.atom(doc: "The type of the option item.") |> Zoi.required(),
            required:
              Zoi.boolean(doc: "Defines if the option item is required.") |> Zoi.default(false),
            keys: Zoi.keyword(Zoi.any(), doc: "Defines which set of keys are accepted."),
            default: Zoi.any(doc: "The default.")
          )

  describe "Zoi.docs/1" do
    test "simple docs for a keyword schema" do
      docs = """
      * `:type` (`t:atom/0`) - Required. The type of the option item.

      * `:required` (`t:boolean/0`) - Defines if the option item is required. The default value is `false`.

      * `:keys` (`t:keyword/0`) - Defines which set of keys are accepted.

      * `:default` (`t:term/0`) - The default.
      """

      assert Zoi.docs(@schema) == docs
    end

    test "simple docs for a object schema" do
      schema =
        Zoi.object(
          name: Zoi.string(doc: "The name of the person."),
          age: Zoi.integer(doc: "The age of the person.") |> Zoi.default(0),
          email: Zoi.string(doc: "The email address.") |> Zoi.optional()
        )

      docs = """
      * `:name` (`t:String.t/0`) - Required. The name of the person.

      * `:age` (`t:integer/0`) - Required. The age of the person. The default value is `0`.

      * `:email` (`t:String.t/0`) - The email address.
      """

      assert Zoi.docs(schema) == docs
    end

    test "docs for nested schemas" do
      schema =
        Zoi.object(%{
          user:
            Zoi.object(
              %{
                id: Zoi.integer(doc: "The user ID."),
                profile:
                  Zoi.object(
                    bio: Zoi.string(doc: "The user bio.") |> Zoi.optional(),
                    website: Zoi.string(doc: "The user website.") |> Zoi.optional()
                  )
              },
              doc: "The user information."
            )
        })

      # For now nesting is not implemented
      docs = """
      * `:user` (`t:map/0`) - Required. The user information.
      """

      assert Zoi.docs(schema) == docs
    end

    test "all types" do
      schema =
        Zoi.keyword(
          any: Zoi.any(),
          array: Zoi.array(Zoi.integer()),
          atom: Zoi.atom(),
          boolean: Zoi.boolean(),
          date: Zoi.date(),
          datetime: Zoi.datetime(),
          decimal: Zoi.decimal(),
          enum: Zoi.enum(a: "A", b: "B"),
          enum_atom: Zoi.enum([:a, :b]),
          float: Zoi.float(),
          integer: Zoi.integer(),
          keyword: Zoi.keyword(Zoi.string()),
          literal: Zoi.literal(42),
          map: Zoi.map(),
          naivedatetime: Zoi.naive_datetime(),
          null: Zoi.null(),
          number: Zoi.number(),
          object: Zoi.object(name: Zoi.string()),
          string: Zoi.string(),
          stringboolean: Zoi.string_boolean(),
          struct: Zoi.struct(SomeStruct, %{name: Zoi.string()}),
          time: Zoi.time(),
          tuple: Zoi.tuple({Zoi.integer(), Zoi.string()}),
          union: Zoi.union([Zoi.integer(), Zoi.string()])
        )

      docs = """
      * `:any` (`t:term/0`)

      * `:array` (list of `t:integer/0`)

      * `:atom` (`t:atom/0`)

      * `:boolean` (`t:boolean/0`)

      * `:date` (`t:Date.t/0`)

      * `:datetime` (`t:DateTime.t/0`)

      * `:decimal` (`t:Decimal.t/0`)

      * `:enum` (one of A, B)

      * `:enum_atom` (one of `:a`, `:b`)

      * `:float` (`t:float/0`)

      * `:integer` (`t:integer/0`)

      * `:keyword` (`t:keyword/0`)

      * `:literal` (`42`)

      * `:map` (`t:map/0`)

      * `:naivedatetime` (`t:NaiveDateTime.t/0`)

      * `:null` (`nil`)

      * `:number` (`t:number/0`)

      * `:object` (`t:map/0`)

      * `:string` (`t:String.t/0`)

      * `:stringboolean` (`t:boolean/0` or `t:String.t/0`)

      * `:struct` (struct of type `SomeStruct`)

      * `:time` (`t:Time.t/0`)

      * `:tuple` (tuple of `t:integer/0`, `t:String.t/0` values)

      * `:union` (`t:integer/0` or `t:String.t/0`)
      """

      assert Zoi.docs(schema) == docs
    end
  end
end
