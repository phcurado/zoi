defmodule Zoi.DescribeTest do
  use ExUnit.Case, async: true

  defmodule User do
    defstruct [:name]
  end

  @schema Zoi.keyword(
            type: Zoi.atom(description: "The type of the option item.") |> Zoi.required(),
            required:
              Zoi.boolean(description: "Defines if the option item is required.")
              |> Zoi.default(false),
            keys: Zoi.keyword(Zoi.any(), description: "Defines which set of keys are accepted."),
            default: Zoi.any(description: "The default.")
          )

  describe "Zoi.describe/1" do
    test "simple docs for a keyword schema" do
      formatted_description = """
      * `:type` (`t:atom/0`) - Required. The type of the option item.

      * `:required` (`t:boolean/0`) - Defines if the option item is required. The default value is `false`.

      * `:keys` (`t:keyword/0`) - Defines which set of keys are accepted.

      * `:default` (`t:term/0`) - The default.
      """

      assert Zoi.describe(@schema) == formatted_description
    end

    test "simple docs for a object schema" do
      schema =
        Zoi.object(
          name: Zoi.string(description: "The name of the person."),
          age: Zoi.integer(description: "The age of the person.") |> Zoi.default(0),
          email: Zoi.string(description: "The email address.") |> Zoi.optional()
        )

      formatted_description = """
      * `:name` (`t:String.t/0`) - Required. The name of the person.

      * `:age` (`t:integer/0`) - Required. The age of the person. The default value is `0`.

      * `:email` (`t:String.t/0`) - The email address.
      """

      assert Zoi.describe(schema) == formatted_description
    end

    test "describe for struct schema" do
      schema =
        Zoi.struct(User, %{
          name: Zoi.string(description: "The name of the struct.")
        })

      formatted_description = """
      * `:name` (`t:String.t/0`) - Required. The name of the struct.
      """

      assert Zoi.describe(schema) == formatted_description
    end

    test "describe should raise for unsupported schemas" do
      schema = Zoi.array(Zoi.integer())

      assert_raise ArgumentError,
                   "Zoi.describe/1 only supports describing keyword, object and struct schemas",
                   fn ->
                     Zoi.describe(schema)
                   end
    end

    test "describe for nested schemas" do
      schema =
        Zoi.object(%{
          user:
            Zoi.object(
              %{
                id: Zoi.integer(description: "The user ID."),
                profile:
                  Zoi.object(
                    bio: Zoi.string(description: "The user bio.") |> Zoi.optional(),
                    website: Zoi.string(description: "The user website.") |> Zoi.optional()
                  )
              },
              description: "The user information."
            )
        })

      # For now nesting is not implemented
      formatted_description = """
      * `:user` (`t:map/0`) - Required. The user information.
      """

      assert Zoi.describe(schema) == formatted_description
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
          function: Zoi.function(),
          integer: Zoi.integer(),
          intersection: Zoi.intersection([Zoi.string(), Zoi.literal("fixed")]),
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
          union: Zoi.union([Zoi.integer(), Zoi.string()]),
          lazy: Zoi.lazy(fn -> Zoi.string() end),
          codec:
            Zoi.codec(Zoi.string(), Zoi.integer(),
              decode: fn x -> x end,
              encode: fn x -> x end
            )
        )

      formatted_description = """
      * `:any` (`t:term/0`)

      * `:array` (list of `t:integer/0`)

      * `:atom` (`t:atom/0`)

      * `:boolean` (`t:boolean/0`)

      * `:date` (`t:Date.t/0`)

      * `:datetime` (`t:DateTime.t/0`)

      * `:decimal` (`t:Decimal.t/0`)

      * `:enum` (one of `"A"`, `"B"`)

      * `:enum_atom` (one of `:a`, `:b`)

      * `:float` (`t:float/0`)

      * `:function` (`t:function/0`)

      * `:integer` (`t:integer/0`)

      * `:intersection` (`t:String.t/0` and `"fixed"`)

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

      * `:lazy` (`t:String.t/0`)

      * `:codec` (`t:integer/0`)
      """

      assert Zoi.describe(schema) == formatted_description
    end

    test "raise if encoder is not implemented for schema" do
      assert_raise ArgumentError,
                   "Describe.Encoder not implemented for schema: %{unsupported: true}",
                   fn ->
                     Zoi.Describe.Encoder.encode(%{unsupported: true})
                   end
    end
  end
end
