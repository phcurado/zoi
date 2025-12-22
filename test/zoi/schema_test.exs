defmodule Zoi.SchemaTest do
  use ExUnit.Case, async: true

  describe "traverse/2" do
    test "enables coercion on nested fields" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer(),
          active: Zoi.boolean()
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Root is not transformed
      refute schema.coerce
      # Nested fields are transformed
      assert schema.fields[:name].coerce == true
      assert schema.fields[:age].coerce == true
      assert schema.fields[:active].coerce == true
    end

    test "applies transformation to deeply nested objects" do
      schema =
        Zoi.map(%{
          user:
            Zoi.map(%{
              name: Zoi.string(),
              address:
                Zoi.map(%{
                  street: Zoi.string(),
                  zip: Zoi.integer()
                })
            })
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      user_field = schema.fields[:user]
      address_field = user_field.fields[:address]

      # Root is not transformed
      refute schema.coerce
      # Nested objects and fields are transformed
      assert user_field.coerce == true
      assert user_field.fields[:name].coerce == true
      assert address_field.coerce == true
      assert address_field.fields[:street].coerce == true
      assert address_field.fields[:zip].coerce == true
    end

    test "applies transformation to arrays" do
      schema =
        Zoi.map(%{
          tags: Zoi.array(Zoi.string()),
          counts: Zoi.array(Zoi.integer())
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      tags_field = schema.fields[:tags]
      counts_field = schema.fields[:counts]

      assert tags_field.coerce == true
      assert tags_field.inner.coerce == true
      assert counts_field.coerce == true
      assert counts_field.inner.coerce == true
    end

    test "applies transformation to nested arrays" do
      schema =
        Zoi.map(%{
          items: Zoi.array(Zoi.map(%{name: Zoi.string()}))
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      items_field = schema.fields[:items]

      assert items_field.coerce == true
      assert items_field.inner.coerce == true
      assert items_field.inner.fields[:name].coerce == true
    end

    test "applies transformation to unions" do
      schema =
        Zoi.map(%{
          value: Zoi.union([Zoi.string(), Zoi.integer()])
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      value_field = schema.fields[:value]
      [string_schema, integer_schema] = value_field.schemas

      assert string_schema.coerce == true
      assert integer_schema.coerce == true
    end

    test "applies transformation to intersections" do
      schema =
        Zoi.map(%{
          value: Zoi.intersection([Zoi.string(), Zoi.string() |> Zoi.min(2)])
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      value_field = schema.fields[:value]
      [schema1, schema2] = value_field.schemas

      assert schema1.coerce == true
      assert schema2.coerce == true
    end

    test "applies transformation to maps" do
      schema =
        Zoi.map(%{
          metadata: Zoi.map(Zoi.string(), Zoi.integer())
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      metadata_field = schema.fields[:metadata]

      # Map itself might not have coerce, but its key and value types should
      assert metadata_field.key_type.coerce == true
      assert metadata_field.value_type.coerce == true
    end

    test "applies transformation to tuples" do
      schema =
        Zoi.map(%{
          pair: Zoi.tuple({Zoi.string(), Zoi.integer()})
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      pair_field = schema.fields[:pair]
      [string_type, integer_type] = pair_field.fields

      assert string_type.coerce == true
      assert integer_type.coerce == true
    end

    test "applies transformation to keywords" do
      schema =
        Zoi.map(%{
          opts: Zoi.keyword(name: Zoi.string(), age: Zoi.integer())
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      opts_field = schema.fields[:opts]

      assert opts_field.coerce == true
      assert opts_field.fields[:name].coerce == true
      assert opts_field.fields[:age].coerce == true
    end

    test "supports keyword as root schema" do
      schema =
        Zoi.keyword(name: Zoi.string(), age: Zoi.integer())
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Root is not transformed
      refute schema.coerce
      # Nested fields are transformed
      assert schema.fields[:name].coerce == true
      assert schema.fields[:age].coerce == true
    end

    test "applies transformation to default wrappers" do
      schema =
        Zoi.map(%{
          name: Zoi.string() |> Zoi.default("unknown")
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      name_field = schema.fields[:name]

      assert name_field.inner.coerce == true
    end

    test "applies transformation to lazy types" do
      schema =
        Zoi.map(%{
          friends: Zoi.array(Zoi.lazy(fn -> Zoi.string() end))
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      friends_field = schema.fields[:friends]

      assert friends_field.coerce == true
      # Lazy type is treated as a leaf node, the function is preserved
      assert is_function(friends_field.inner.fun, 0)
    end

    test "applies nullish conditionally using path" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer()
        })
        |> Zoi.Schema.traverse(fn node, path ->
          # Apply nullish only to leaf fields, not the object itself
          if path != [] do
            Zoi.nullish(node)
          else
            node
          end
        end)

      name_field = schema.fields[:name]
      age_field = schema.fields[:age]

      # nullish wraps in a union with null
      assert %Zoi.Types.Union{} = name_field
      assert %Zoi.Types.Union{} = age_field
    end

    test "can chain multiple transformations" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer()
        })
        |> Zoi.Schema.traverse(fn node, path ->
          if path != [] do
            Zoi.nullish(node)
          else
            node
          end
        end)
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Root is not transformed
      refute schema.coerce
      # Fields are wrapped in nullish (Union), but Union also gets coerce enabled
      name_field = schema.fields[:name]
      # Union types don't have coerce field, but their inner schemas do
      assert %Zoi.Types.Union{} = name_field
    end

    test "can conditionally apply transformation based on path" do
      schema =
        Zoi.map(%{
          password: Zoi.string(),
          email: Zoi.string(),
          profile:
            Zoi.map(%{
              password: Zoi.string(),
              bio: Zoi.string()
            })
        })
        |> Zoi.Schema.traverse(fn node, path ->
          if :password in path do
            node
          else
            Zoi.coerce(node)
          end
        end)

      # Root is not transformed
      refute schema.coerce
      # Email should have coercion
      assert schema.fields[:email].coerce == true

      # Password fields should NOT have coercion
      refute schema.fields[:password].coerce
      profile_field = schema.fields[:profile]
      refute profile_field.fields[:password].coerce

      # But profile itself and bio should have coercion
      assert profile_field.coerce == true
      assert profile_field.fields[:bio].coerce == true
    end

    test "make all fields nullable with coercion" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer(),
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Schema.traverse(&Zoi.nullish/1)
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Should parse with null values
      assert {:ok, result} = Zoi.parse(schema, %{name: nil, age: nil, tags: nil})
      assert result.name == nil
      assert result.age == nil
      assert result.tags == nil

      # Should also parse with coerced values
      assert {:ok, result} = Zoi.parse(schema, %{name: "John", age: "30", tags: ["a", "b"]})
      assert result.name == "John"
      assert result.age == 30
      assert result.tags == ["a", "b"]
    end

    test "apply transformations conditionally based on path" do
      schema =
        Zoi.map(%{
          password: Zoi.string(),
          email: Zoi.string(),
          age: Zoi.integer()
        })
        |> Zoi.Schema.traverse(fn node, path ->
          case path do
            [:password] -> node
            [:email] -> Zoi.coerce(node)
            [:age] -> node |> Zoi.coerce() |> Zoi.default(0)
            _ -> node
          end
        end)

      # Password should not have coercion
      refute schema.fields[:password].coerce
      # Email should have coercion
      assert schema.fields[:email].coerce
      # Age should have coercion and default
      assert schema.fields[:age].inner.coerce

      assert {:ok, %{age: 0}} =
               Zoi.parse(schema, %{password: "secret", email: "test@example.com", age: nil})
    end

    test "apply coercion everywhere like Form.prepare" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer(),
          user:
            Zoi.map(%{
              email: Zoi.string()
            })
        })
        |> Zoi.Schema.traverse(&Zoi.coerce/1)
        # Apply to root manually
        |> Zoi.coerce()

      assert schema.coerce == true
      assert schema.fields[:name].coerce == true
      assert schema.fields[:age].coerce == true

      user_field = schema.fields[:user]
      assert user_field.coerce == true
      assert user_field.fields[:email].coerce == true
    end

    test "supports keyword with schema as root" do
      schema =
        Zoi.keyword(Zoi.string())
        |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Root is not transformed
      refute schema.coerce
      # The inner schema should be transformed
      assert schema.fields.coerce == true
    end

    test "handles primitive schemas at root level" do
      string_schema = Zoi.string() |> Zoi.Schema.traverse(&Zoi.coerce/1)
      integer_schema = Zoi.integer() |> Zoi.Schema.traverse(&Zoi.coerce/1)
      boolean_schema = Zoi.boolean() |> Zoi.Schema.traverse(&Zoi.coerce/1)

      # Primitive schemas have no children to traverse, so they remain unchanged
      refute string_schema.coerce
      refute integer_schema.coerce
      refute boolean_schema.coerce
    end
  end
end
