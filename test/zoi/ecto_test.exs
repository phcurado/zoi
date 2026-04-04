defmodule Zoi.EctoTest do
  use ExUnit.Case, async: true

  defmodule SimpleSchema do
    require Zoi.Ecto

    @schema Zoi.map(%{
              name: Zoi.string(),
              age: Zoi.integer(),
              active: Zoi.boolean(),
              role: Zoi.enum([:admin, :user]),
              priority: Zoi.enum([1, 2, 3]),
              color: Zoi.enum(["red", "green"]),
              type: Zoi.literal("event"),
              code: Zoi.literal(42),
              ratio: Zoi.literal(1.5),
              flag: Zoi.literal(true),
              tag: Zoi.literal(:info),
              metadata: Zoi.map(),
              extra: Zoi.any()
            })

    Zoi.Ecto.generate_embedded_schema(@schema)
  end

  defmodule NestedSchema do
    require Zoi.Ecto

    @schema Zoi.map(%{
              email: Zoi.email(),
              address:
                Zoi.map(%{
                  street: Zoi.string(),
                  number: Zoi.integer()
                })
            })

    Zoi.Ecto.generate_embedded_schema(@schema)
  end

  defmodule ArraySchema do
    require Zoi.Ecto

    @schema Zoi.map(%{
              tags: Zoi.array(Zoi.string()),
              addresses:
                Zoi.array(
                  Zoi.map(%{
                    street: Zoi.string()
                  })
                )
            })

    Zoi.Ecto.generate_embedded_schema(@schema)
  end

  defmodule TypesSchema do
    require Zoi.Ecto

    @schema Zoi.map(%{
              a_string: Zoi.string(),
              a_integer: Zoi.integer(),
              a_float: Zoi.float(),
              a_boolean: Zoi.boolean(),
              a_date: Zoi.date(),
              a_time: Zoi.time(),
              a_datetime: Zoi.datetime(),
              a_naive_datetime: Zoi.naive_datetime(),
              a_decimal: Zoi.decimal()
            })

    Zoi.Ecto.generate_embedded_schema(@schema)
  end

  defmodule DefaultSchema do
    require Zoi.Ecto

    @schema Zoi.map(%{
              role: Zoi.string() |> Zoi.default("user"),
              count: Zoi.integer() |> Zoi.default(0)
            })

    Zoi.Ecto.generate_embedded_schema(@schema)
  end

  defmodule NullableSchema do
    require Zoi.Ecto

    @schema Zoi.map(%{
              name: Zoi.string(),
              nickname: Zoi.nullable(Zoi.string()),
              settings: Zoi.nullable(Zoi.map(%{}))
            })

    Zoi.Ecto.generate_embedded_schema(@schema)
  end

  defmodule RefinedSchema do
    require Zoi.Ecto

    def validate_combo(%{name: "invalid_combo"}, _opts), do: {:error, "invalid combination"}
    def validate_combo(_, _opts), do: :ok

    @schema Zoi.map(%{name: Zoi.string()})
            |> Zoi.refine({__MODULE__, :validate_combo, []})

    Zoi.Ecto.generate_embedded_schema(@schema)
  end

  describe "generate_embedded_schema/1" do
    test "generates struct with fields" do
      schema = %SimpleSchema{}
      refute schema.name
      refute schema.age
      refute schema.active
    end

    test "generates __zoi_schema__/0" do
      assert %Zoi.Types.Map{} = SimpleSchema.__zoi_schema__()
    end

    test "does not generate primary key" do
      refute Map.has_key?(%SimpleSchema{}, :id)
    end

    test "generates nested embeds_one" do
      schema = %NestedSchema{}
      refute schema.email
      refute schema.address
    end

    test "generates embeds_many for array of maps" do
      assert %ArraySchema{tags: nil, addresses: []} = %ArraySchema{}
    end

    test "generates fields with default values" do
      assert %DefaultSchema{role: "user", count: 0} = %DefaultSchema{}
    end

    test "generates nullable fields" do
      schema = %NullableSchema{}
      refute schema.name
      refute schema.nickname
    end

    test "maps all primitive types" do
      schema = %TypesSchema{}
      refute schema.a_string
      refute schema.a_integer
      refute schema.a_float
      refute schema.a_boolean
      refute schema.a_date
      refute schema.a_time
      refute schema.a_datetime
      refute schema.a_naive_datetime
      refute schema.a_decimal
    end
  end

  describe "changeset/2" do
    test "valid input returns valid changeset" do
      changeset =
        Zoi.Ecto.changeset(%SimpleSchema{}, %{
          name: "John",
          age: 30,
          active: true,
          role: :admin,
          priority: 1,
          color: "red",
          type: "event",
          code: 42,
          ratio: 1.5,
          flag: true,
          tag: :info,
          metadata: %{foo: "bar"},
          extra: %{anything: true}
        })

      assert changeset.valid?
      assert %{name: "John", age: 30, active: true, role: :admin} = changeset.changes
      assert changeset.errors == []
    end

    test "invalid input returns invalid changeset with errors" do
      changeset = Zoi.Ecto.changeset(%SimpleSchema{}, %{name: 123, age: "not_int", active: true})

      refute changeset.valid?
      assert {"invalid type: expected string", _} = changeset.errors[:name]
      assert {"invalid type: expected integer", _} = changeset.errors[:age]
    end

    test "missing required fields returns errors" do
      changeset = Zoi.Ecto.changeset(%SimpleSchema{}, %{})

      refute changeset.valid?
      assert {"is required", _} = changeset.errors[:name]
      assert {"is required", _} = changeset.errors[:age]
      assert {"is required", _} = changeset.errors[:active]
    end

    test "nested valid input" do
      changeset =
        Zoi.Ecto.changeset(%NestedSchema{}, %{
          email: "test@example.com",
          address: %{street: "Main St", number: 42}
        })

      assert changeset.valid?

      assert %{
               email: "test@example.com",
               address: %Ecto.Changeset{
                 valid?: true,
                 changes: %{street: "Main St", number: 42}
               }
             } = changeset.changes
    end

    test "nested errors land on the embedded changeset" do
      changeset =
        Zoi.Ecto.changeset(%NestedSchema{}, %{
          email: "test@example.com",
          address: %{street: "Main St"}
        })

      refute changeset.valid?
      assert changeset.errors == []

      assert %Ecto.Changeset{valid?: false} = changeset.changes.address
      assert {"is required", _} = changeset.changes.address.errors[:number]
    end

    test "parent and nested errors together" do
      changeset =
        Zoi.Ecto.changeset(%NestedSchema{}, %{
          email: "invalid",
          address: %{street: "Main St"}
        })

      refute changeset.valid?
      assert {"invalid email format", _} = changeset.errors[:email]

      assert %Ecto.Changeset{valid?: false} = changeset.changes.address
      assert {"is required", _} = changeset.changes.address.errors[:number]
    end

    test "apply_changes on valid changeset returns struct" do
      changeset =
        Zoi.Ecto.changeset(%SimpleSchema{}, %{
          name: "John",
          age: 30,
          active: true,
          role: :admin,
          priority: 1,
          color: "red",
          type: "event",
          code: 42,
          ratio: 1.5,
          flag: true,
          tag: :info,
          metadata: %{foo: "bar"},
          extra: %{anything: true}
        })

      result = Ecto.Changeset.apply_changes(changeset)
      assert %SimpleSchema{name: "John", age: 30, active: true, role: :admin} = result
    end

    test "defaults are applied in struct" do
      changeset = Zoi.Ecto.changeset(%DefaultSchema{}, %{})

      assert changeset.valid?

      result = Ecto.Changeset.apply_changes(changeset)
      assert %DefaultSchema{role: "user", count: 0} = result
    end

    test "nullable fields accept nil" do
      changeset =
        Zoi.Ecto.changeset(%NullableSchema{}, %{name: "John", nickname: nil, settings: nil})

      assert changeset.valid?
      assert %{name: "John"} = changeset.changes
    end

    test "base-level refinement error" do
      changeset =
        Zoi.Ecto.changeset(%RefinedSchema{}, %{name: "invalid_combo", extra: "anything"})

      refute changeset.valid?
      assert {"invalid combination", _} = changeset.errors[:base]
    end

    test "array of maps changeset" do
      changeset =
        Zoi.Ecto.changeset(%ArraySchema{}, %{
          tags: ["elixir", "ecto"],
          addresses: [%{street: "Main St"}, %{street: "Oak Ave"}]
        })

      assert changeset.valid?
      assert %{tags: ["elixir", "ecto"]} = changeset.changes
    end
  end
end
