defmodule Zoi.FormTest do
  use ExUnit.Case, async: true

  defmodule TestUser do
    defstruct [:name]
  end

  describe "Zoi.Form.prepare/1" do
    test "enables coercion on object" do
      schema =
        Zoi.object(%{
          age: Zoi.integer()
        })
        |> Zoi.Form.prepare()

      assert schema.coerce == true
      assert schema.empty_values == [nil, ""]
    end

    test "enables coercion on nested objects" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{age: Zoi.integer()})
        })
        |> Zoi.Form.prepare()

      user_field = schema.fields[:user]
      assert user_field.coerce == true
    end

    test "enables coercion on arrays" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.integer())
        })
        |> Zoi.Form.prepare()

      tags_field = schema.fields[:tags]
      assert tags_field.coerce == true
    end

    test "enables coercion on nested arrays" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{name: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      items_field = schema.fields[:items]
      assert items_field.coerce == true
      assert items_field.inner.coerce == true
    end

    test "enables coercion on keyword fields" do
      schema =
        Zoi.object(%{
          opts: Zoi.keyword(name: Zoi.string(), age: Zoi.integer())
        })
        |> Zoi.Form.prepare()

      opts_field = schema.fields[:opts]
      assert opts_field.coerce == true
    end

    test "enables coercion on keyword with schema value" do
      schema =
        Zoi.object(%{
          opts: Zoi.keyword(Zoi.string())
        })
        |> Zoi.Form.prepare()

      opts_field = schema.fields[:opts]
      assert opts_field.coerce == true
      # The inner schema should also have coercion enabled
      assert opts_field.fields.coerce == true
    end

    test "enables coercion on maps" do
      schema =
        Zoi.object(%{
          data: Zoi.map(Zoi.string(), Zoi.integer())
        })
        |> Zoi.Form.prepare()

      data_field = schema.fields[:data]
      # Maps coerce their key and value types
      assert data_field.key_type.coerce == true
      assert data_field.value_type.coerce == true
    end

    test "enables coercion on tuples" do
      schema =
        Zoi.object(%{
          coords: Zoi.tuple({Zoi.float(), Zoi.float()})
        })
        |> Zoi.Form.prepare()

      coords_field = schema.fields[:coords]
      # Tuples get enhanced with coercion on inner fields
      [first, second] = coords_field.fields
      assert first.coerce == true
      assert second.coerce == true
    end

    test "enables coercion on unions" do
      schema =
        Zoi.object(%{
          value: Zoi.union([Zoi.string(), Zoi.integer()])
        })
        |> Zoi.Form.prepare()

      value_field = schema.fields[:value]
      # Union schemas have coercion enabled
      assert Enum.all?(value_field.schemas, & &1.coerce)
    end

    test "enables coercion on intersections" do
      schema =
        Zoi.object(%{
          value:
            Zoi.intersection([Zoi.object(%{a: Zoi.string()}), Zoi.object(%{b: Zoi.string()})])
        })
        |> Zoi.Form.prepare()

      value_field = schema.fields[:value]
      # Intersection schemas have coercion enabled
      assert Enum.all?(value_field.schemas, & &1.coerce)
    end

    test "enables coercion on struct types" do
      schema =
        Zoi.struct(TestUser, %{
          user: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      user_field = schema.fields[:user]
      assert user_field.coerce == true
    end

    test "enables coercion on nested struct types" do
      schema =
        Zoi.object(%{
          account:
            Zoi.struct(TestUser, %{
              name: Zoi.string()
            })
        })
        |> Zoi.Form.prepare()

      account_field = schema.fields[:account]
      assert account_field.coerce == true
    end

    test "enables coercion on default wrapped types" do
      schema =
        Zoi.object(%{
          age: Zoi.integer() |> Zoi.default(0)
        })
        |> Zoi.Form.prepare()

      age_field = schema.fields[:age]
      assert age_field.inner.coerce == true
    end

    test "enables coercion on struct with nested struct" do
      schema =
        Zoi.struct(TestUser, %{
          profile: Zoi.struct(TestUser, %{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      profile_field = schema.fields[:profile]
      assert profile_field.coerce == true
    end

    test "enables coercion on struct with keyword list fields" do
      schema =
        Zoi.struct(TestUser, %{
          opts: Zoi.keyword(name: Zoi.string(), age: Zoi.integer())
        })
        |> Zoi.Form.prepare()

      opts_field = schema.fields[:opts]
      assert opts_field.coerce == true
    end

    test "enables coercion on struct with keyword schema" do
      schema =
        Zoi.struct(TestUser, %{
          opts: Zoi.keyword(Zoi.string())
        })
        |> Zoi.Form.prepare()

      opts_field = schema.fields[:opts]
      assert opts_field.coerce == true
      assert opts_field.fields.coerce == true
    end
  end

  describe "parse/2" do
    test "normalizes single-level array from map to list" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{
        "tags" => %{
          "0" => "first",
          "1" => "second",
          "2" => "third"
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["tags"] == ["first", "second", "third"]
    end

    test "normalizes nested arrays" do
      schema =
        Zoi.object(%{
          matrix: Zoi.array(Zoi.array(Zoi.integer()))
        })
        |> Zoi.Form.prepare()

      params = %{
        "matrix" => %{
          "0" => %{"0" => "1", "1" => "2"},
          "1" => %{"0" => "3", "1" => "4"}
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      # Normalized to lists (strings not yet coerced)
      assert ctx.input["matrix"] == [
               ["1", "2"],
               ["3", "4"]
             ]

      # But parsed data is coerced
      assert ctx.parsed == %{matrix: [[1, 2], [3, 4]]}
    end

    test "normalizes arrays within objects" do
      schema =
        Zoi.object(%{
          user:
            Zoi.object(%{
              tags: Zoi.array(Zoi.string())
            })
        })
        |> Zoi.Form.prepare()

      params = %{
        "user" => %{
          "tags" => %{"0" => "a", "1" => "b"}
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["user"]["tags"] == ["a", "b"]
    end

    test "normalizes arrays of objects with arrays" do
      schema =
        Zoi.object(%{
          users:
            Zoi.array(
              Zoi.object(%{
                tags: Zoi.array(Zoi.string())
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "users" => %{
          "0" => %{"tags" => %{"0" => "tag1"}},
          "1" => %{"tags" => %{"0" => "tag2"}}
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["users"] == [
               %{"tags" => ["tag1"]},
               %{"tags" => ["tag2"]}
             ]
    end

    test "handles empty map as empty list" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{"tags" => %{}}
      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["tags"] == []
    end

    test "handles already-normalized lists" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{"tags" => ["a", "b", "c"]}
      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["tags"] == ["a", "b", "c"]
    end

    test "handles single map without numeric keys as single-item list" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{name: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      params = %{
        "items" => %{
          "_persistent_id" => "0",
          "name" => "Solo"
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["items"] == [%{"_persistent_id" => "0", "name" => "Solo"}]
    end

    test "preserves non-array map fields" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string()}),
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{
        "user" => %{"name" => "John"},
        "tags" => %{"0" => "a"}
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["user"] == %{"name" => "John"}
      assert ctx.input["tags"] == ["a"]
    end

    test "handles nil values" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string()) |> Zoi.optional()
        })
        |> Zoi.Form.prepare()

      params = %{"tags" => nil}
      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["tags"] == nil
    end

    test "handles missing fields" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string()) |> Zoi.optional()
        })
        |> Zoi.Form.prepare()

      params = %{}
      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input == %{}
    end

    test "normalizes arrays with default wrapper" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string()) |> Zoi.default([])
        })
        |> Zoi.Form.prepare()

      params = %{
        "tags" => %{"0" => "a", "1" => "b"}
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["tags"] == ["a", "b"]
    end

    test "sorts numeric keys correctly" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # Keys out of order
      params = %{
        "items" => %{
          "10" => "tenth",
          "2" => "second",
          "1" => "first",
          "20" => "twentieth"
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["items"] == ["first", "second", "tenth", "twentieth"]
    end

    test "ignores non-numeric keys when numeric keys present" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{
        "items" => %{
          "_persistent_id" => "ignored",
          "_unused" => "also ignored",
          "0" => "first",
          "1" => "second"
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["items"] == ["first", "second"]
    end

    test "handles integer keys" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{
        "items" => %{
          0 => "first",
          1 => "second"
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["items"] == ["first", "second"]
    end

    test "handles non-map input gracefully" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # Non-map input should pass through
      ctx = Zoi.Form.parse(schema, nil)
      refute ctx.valid?
    end

    test "handles mixed values in map_to_list" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # Already a list - should stay as list
      ctx = Zoi.Form.parse(schema, %{"items" => ["a", "b"]})
      assert ctx.input["items"] == ["a", "b"]

      # Nil - should stay nil
      ctx = Zoi.Form.parse(schema, %{"items" => nil})
      assert ctx.input["items"] == nil

      # Other non-map, non-list values
      ctx = Zoi.Form.parse(schema, %{"items" => 42})
      assert ctx.input["items"] == 42
    end

    test "normalizes deeply nested structure" do
      schema =
        Zoi.object(%{
          level1:
            Zoi.array(
              Zoi.object(%{
                level2:
                  Zoi.array(
                    Zoi.object(%{
                      level3: Zoi.array(Zoi.string())
                    })
                  )
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "level1" => %{
          "0" => %{
            "level2" => %{
              "0" => %{
                "level3" => %{"0" => "deep"}
              }
            }
          }
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.input["level1"] == [
               %{
                 "level2" => [
                   %{"level3" => ["deep"]}
                 ]
               }
             ]
    end

    test "handles mixed object and keyword schemas" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{name: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      params = %{
        "items" => %{"0" => %{"name" => "test"}}
      }

      ctx = Zoi.Form.parse(schema, params)

      assert ctx.valid?
      assert ctx.parsed == %{items: [%{name: "test"}]}
    end
  end
end
