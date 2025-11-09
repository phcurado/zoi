defmodule Zoi.FormDataTest do
  use ExUnit.Case, async: true

  alias Phoenix.HTML.FormData

  describe "input normalization" do
    test "normalizes LiveView map arrays to lists in ctx.input" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # LiveView sends this format
      params = %{
        "tags" => %{
          "0" => "first",
          "1" => "second",
          "2" => "third"
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      # ctx.input should have normalized arrays
      assert ctx.input["tags"] == ["first", "second", "third"]
      assert is_list(ctx.input["tags"])
    end

    test "normalizes nested array structures" do
      schema =
        Zoi.object(%{
          departments:
            Zoi.array(
              Zoi.object(%{
                name: Zoi.string(),
                employees: Zoi.array(Zoi.string())
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "departments" => %{
          "0" => %{
            "name" => "Engineering",
            "employees" => %{"0" => "Alice", "1" => "Bob"}
          }
        }
      }

      ctx = Zoi.Form.parse(schema, params)

      # Both levels should be normalized to lists
      assert ctx.input["departments"] == [
               %{"name" => "Engineering", "employees" => ["Alice", "Bob"]}
             ]

      assert is_list(ctx.input["departments"])
      assert is_list(hd(ctx.input["departments"])["employees"])
    end

    test "handles already-normalized lists" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{"tags" => ["a", "b", "c"]}
      ctx = Zoi.Form.parse(schema, params)

      # Should remain as list
      assert ctx.input["tags"] == ["a", "b", "c"]
    end

    test "handles empty arrays" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{"tags" => %{}}
      ctx = Zoi.Form.parse(schema, params)

      # Empty map should become empty list
      assert ctx.input["tags"] == []
    end

    test "form.params also has normalized arrays" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # LiveView map format
      params = %{"tags" => %{"0" => "a", "1" => "b"}}
      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :post)

      # form.params should have normalized list
      assert form.params["tags"] == ["a", "b"]
      assert is_list(form.params["tags"])
    end
  end

  describe "Zoi.Form.prepare/1" do
    test "enables coercion on all fields" do
      schema =
        Zoi.object(%{
          age: Zoi.integer(),
          active: Zoi.boolean()
        })
        |> Zoi.Form.prepare()

      # String values should be coerced
      ctx = Zoi.Form.parse(schema, %{"age" => "30", "active" => "true"})

      assert ctx.valid?
      assert ctx.parsed == %{age: 30, active: true}
    end

    test "sets empty values to nil and empty string" do
      schema =
        Zoi.object(%{
          name: Zoi.string()
        })
        |> Zoi.Form.prepare()

      # nil should trigger required error
      ctx = Zoi.Form.parse(schema, %{"name" => nil})
      refute ctx.valid?
      assert [%Zoi.Error{code: :required}] = ctx.errors

      # Empty string should also trigger required error
      ctx = Zoi.Form.parse(schema, %{"name" => ""})
      refute ctx.valid?
      assert [%Zoi.Error{code: :required}] = ctx.errors
    end

    test "enables coercion on nested objects" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{age: Zoi.integer()})
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"user" => %{"age" => "25"}})

      assert ctx.valid?
      assert ctx.parsed == %{user: %{age: 25}}
    end

    test "enables coercion on nested arrays" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.integer())
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"tags" => ["1", "2", "3"]})

      assert ctx.valid?
      assert ctx.parsed == %{tags: [1, 2, 3]}
    end
  end

  describe "Phoenix.HTML.FormData implementation" do
    test "converts context to form with params and errors" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(3),
          email: Zoi.email()
        })
        |> Zoi.Form.prepare()

      # Invalid params
      params = %{"name" => "Jo", "email" => "invalid"}
      ctx = Zoi.Form.parse(schema, params)

      form = FormData.to_form(ctx, as: :user)

      assert form.name == "user"
      assert form.params == params
      assert form.source == ctx

      # Check errors are present
      assert {:name, _} = List.keyfind(form.errors, :name, 0)
      assert {:email, _} = List.keyfind(form.errors, :email, 0)
    end

    test "preserves params even when validation fails" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(3)
        })
        |> Zoi.Form.prepare()

      params = %{"name" => "Jo"}
      ctx = Zoi.Form.parse(schema, params)

      refute ctx.valid?

      form = FormData.to_form(ctx, as: :user)

      # Params should be preserved for display
      assert FormData.input_value(ctx, form, :name) == "Jo"
    end

    test "returns validated data when valid" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(3),
          age: Zoi.integer()
        })
        |> Zoi.Form.prepare()

      params = %{"name" => "John", "age" => "30"}
      ctx = Zoi.Form.parse(schema, params)

      assert ctx.valid?

      form = FormData.to_form(ctx, as: :user)

      # form.data should contain the validated, coerced data
      assert form.data == %{name: "John", age: 30}
    end
  end

  describe "nested forms for objects" do
    test "builds nested form for object field" do
      schema =
        Zoi.object(%{
          profile:
            Zoi.object(%{
              bio: Zoi.string() |> Zoi.max(100)
            })
        })
        |> Zoi.Form.prepare()

      params = %{"profile" => %{"bio" => "Hello world"}}
      ctx = Zoi.Form.parse(schema, params)

      form = FormData.to_form(ctx, as: :user)
      [profile_form] = FormData.to_form(ctx, form, :profile, [])

      assert profile_form.name == "user[profile]"
      assert FormData.input_value(ctx, profile_form, :bio) == "Hello world"
    end

    test "shows nested object errors" do
      schema =
        Zoi.object(%{
          profile:
            Zoi.object(%{
              bio: Zoi.string() |> Zoi.max(10)
            })
        })
        |> Zoi.Form.prepare()

      params = %{"profile" => %{"bio" => "This is way too long"}}
      ctx = Zoi.Form.parse(schema, params)

      refute ctx.valid?

      form = FormData.to_form(ctx, as: :user)
      [profile_form] = FormData.to_form(ctx, form, :profile, [])

      assert {:bio, _} = List.keyfind(profile_form.errors, :bio, 0)
    end
  end

  describe "nested forms for arrays" do
    test "builds multiple forms for array of objects" do
      schema =
        Zoi.object(%{
          addresses:
            Zoi.array(
              Zoi.object(%{
                street: Zoi.string(),
                city: Zoi.string()
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "addresses" => [
          %{"street" => "Main St", "city" => "NYC"},
          %{"street" => "Second Ave", "city" => "LA"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :company)
      address_forms = FormData.to_form(ctx, form, :addresses, [])

      assert length(address_forms) == 2

      [first, second] = address_forms

      assert first.name == "company[addresses][0]"
      assert FormData.input_value(ctx, first, :street) == "Main St"
      assert FormData.input_value(ctx, first, :city) == "NYC"

      assert second.name == "company[addresses][1]"
      assert FormData.input_value(ctx, second, :street) == "Second Ave"
      assert FormData.input_value(ctx, second, :city) == "LA"
    end

    test "handles empty arrays" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{"tags" => []}
      ctx = Zoi.Form.parse(schema, params)

      form = FormData.to_form(ctx, as: :post)
      tag_forms = FormData.to_form(ctx, form, :tags, [])

      assert tag_forms == []
    end

    test "shows errors for specific array items" do
      schema =
        Zoi.object(%{
          addresses:
            Zoi.array(
              Zoi.object(%{
                street: Zoi.string() |> Zoi.min(5),
                zip: Zoi.integer(coerce: true)
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "addresses" => [
          %{"street" => "Main", "zip" => "1000"},
          %{"street" => "X", "zip" => "invalid"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      refute ctx.valid?

      form = FormData.to_form(ctx, as: :user)
      [first_form, second_form] = FormData.to_form(ctx, form, :addresses, [])

      # First form should have street error only
      assert {:street, _} = List.keyfind(first_form.errors, :street, 0)
      refute List.keyfind(first_form.errors, :zip, 0)

      # Second form should have both errors
      assert {:street, _} = List.keyfind(second_form.errors, :street, 0)
      assert {:zip, _} = List.keyfind(second_form.errors, :zip, 0)
    end
  end

  describe "partial parsing with arrays" do
    test "preserves valid entries when siblings fail" do
      schema =
        Zoi.object(%{
          items:
            Zoi.array(
              Zoi.object(%{
                name: Zoi.string() |> Zoi.min(2),
                price: Zoi.integer(coerce: true)
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "items" => [
          %{"name" => "Valid", "price" => "100"},
          %{"name" => "X", "price" => "oops"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      refute ctx.valid?

      # First valid item should be in parsed
      assert ctx.parsed[:items] == [%{name: "Valid", price: 100}]

      # But params should preserve both for form display
      form = FormData.to_form(ctx, as: :order)
      item_forms = FormData.to_form(ctx, form, :items, [])

      assert length(item_forms) == 2

      # First form has validated data
      assert List.first(item_forms).data[:price] == 100

      # Second form has params for re-display
      assert FormData.input_value(ctx, List.last(item_forms), :price) == "oops"
    end
  end

  describe "LiveView numeric key map format" do
    test "handles maps with numeric string keys" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.object(%{label: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      # LiveView sometimes sends arrays as maps with numeric keys
      params = %{
        "tags" => %{
          "0" => %{"label" => "First"},
          "1" => %{"label" => "Second"}
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :post)
      tag_forms = FormData.to_form(ctx, form, :tags, [])

      assert length(tag_forms) == 2

      labels = Enum.map(tag_forms, &FormData.input_value(ctx, &1, :label))
      assert labels == ["First", "Second"]
    end

    test "preserves correct order with numeric keys" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{value: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      # Keys might come in any order
      params = %{
        "items" => %{
          "2" => %{"value" => "Third"},
          "0" => %{"value" => "First"},
          "1" => %{"value" => "Second"}
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :list)
      item_forms = FormData.to_form(ctx, form, :items, [])

      values = Enum.map(item_forms, &FormData.input_value(ctx, &1, :value))
      assert values == ["First", "Second", "Third"]
    end

    test "ignores Phoenix metadata keys like _persistent_id" do
      schema =
        Zoi.object(%{
          addresses: Zoi.array(Zoi.object(%{city: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      params = %{
        "addresses" => %{
          "_persistent_id" => "some-id",
          "_unused_city" => "",
          "0" => %{"city" => "NYC"}
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :user)
      address_forms = FormData.to_form(ctx, form, :addresses, [])

      # Should only have one form (the "0" key), ignoring metadata
      assert length(address_forms) == 1
      assert FormData.input_value(ctx, List.first(address_forms), :city) == "NYC"
    end

    test "handles single object map without numeric keys" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.object(%{name: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      # Sometimes LiveView sends a single object without array wrapping
      params = %{
        "tags" => %{
          "_persistent_id" => "0",
          "name" => "Solo"
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :post)
      tag_forms = FormData.to_form(ctx, form, :tags, [])

      # Should create single form
      assert length(tag_forms) == 1
      assert FormData.input_value(ctx, List.first(tag_forms), :name) == "Solo"
    end
  end

  describe "dynamic array manipulation" do
    test "adding items works by updating params" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # Start with two tags
      params = %{"tags" => ["ruby", "elixir"]}
      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :post)

      # Add a new tag
      updated_params = Map.put(form.params, "tags", form.params["tags"] ++ ["phoenix"])
      new_ctx = Zoi.Form.parse(schema, updated_params)
      new_form = FormData.to_form(new_ctx, as: :post)

      assert new_form.params["tags"] == ["ruby", "elixir", "phoenix"]
      assert new_ctx.parsed[:tags] == ["ruby", "elixir", "phoenix"]
    end

    test "removing items works by updating params" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{name: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      params = %{
        "items" => [
          %{"name" => "First"},
          %{"name" => "Second"},
          %{"name" => "Third"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :list)

      # Remove middle item (index 1)
      updated_params = Map.put(form.params, "items", List.delete_at(form.params["items"], 1))
      new_ctx = Zoi.Form.parse(schema, updated_params)
      new_form = FormData.to_form(new_ctx, as: :list)

      names = Enum.map(new_ctx.parsed[:items], & &1.name)
      assert names == ["First", "Third"]

      item_forms = FormData.to_form(new_ctx, new_form, :items, [])
      assert length(item_forms) == 2
    end
  end

  describe "form action modes" do
    test "errors are empty when action is :ignore" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(5)
        })
        |> Zoi.Form.prepare()

      params = %{"name" => "Jo"}
      ctx = Zoi.Form.parse(schema, params)

      refute ctx.valid?

      # With :ignore action, errors should not be shown
      form = FormData.to_form(ctx, as: :user, action: :ignore)
      assert form.errors == []
    end

    test "errors are shown when action is :validate" do
      schema =
        Zoi.object(%{
          email: Zoi.email()
        })
        |> Zoi.Form.prepare()

      params = %{"email" => "invalid"}
      ctx = Zoi.Form.parse(schema, params)

      refute ctx.valid?

      form = FormData.to_form(ctx, as: :user, action: :validate)
      assert {:email, _} = List.keyfind(form.errors, :email, 0)
    end
  end

  describe "scope_nested edge cases" do
    test "handles non-map data and params" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      # When data/params are not maps (edge case)
      ctx = Zoi.Form.parse(schema, %{})
      form = FormData.to_form(ctx, as: :data)

      # Accessing nested field when parent is missing
      user_forms = FormData.to_form(ctx, form, :user, default: %{})
      assert length(user_forms) == 1
    end

    test "handles keyword list in data" do
      schema =
        Zoi.object(%{
          opts: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      params = %{"opts" => %{"name" => "test"}}
      ctx = Zoi.Form.parse(schema, params)

      # Create form with keyword list in data (edge case)
      ctx_with_keyword = %{ctx | parsed: %{opts: [name: "test"]}}
      form = FormData.to_form(ctx_with_keyword, as: :config)
      opts_forms = FormData.to_form(ctx_with_keyword, form, :opts, [])

      assert length(opts_forms) == 1
    end

    test "handles atom keys in params" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      # Params with atom keys instead of strings
      ctx = Zoi.Form.parse(schema, %{"user" => %{"name" => "John"}})

      form_with_atom_params = %{
        FormData.to_form(ctx, as: :data)
        | params: %{user: %{"name" => "John"}}
      }

      user_forms = FormData.to_form(ctx, form_with_atom_params, :user, [])
      assert length(user_forms) == 1
    end

    test "handles missing nested fields" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string()}) |> Zoi.optional()
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{})
      form = FormData.to_form(ctx, as: :data)

      # Access missing optional field
      user_forms = FormData.to_form(ctx, form, :user, default: %{})
      assert length(user_forms) == 1
    end
  end

  describe "list_or_empty_maps edge cases" do
    test "handles non-list non-map values" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.string()) |> Zoi.optional()
        })
        |> Zoi.Form.prepare()

      # Pass invalid type for array field
      ctx = Zoi.Form.parse(schema, %{"items" => 42})
      form = FormData.to_form(ctx, as: :data)

      # Should handle gracefully
      item_forms = FormData.to_form(ctx, form, :items, [])
      assert item_forms == []
    end

    test "handles single map without numeric keys" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.object(%{label: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      # Single object without numeric keys
      params = %{
        "tags" => %{
          "_persistent_id" => "0",
          "label" => "Test"
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :post)
      tag_forms = FormData.to_form(ctx, form, :tags, [])

      # Single non-numeric map becomes single-item array
      assert length(tag_forms) == 1
    end
  end

  describe "input_value variations" do
    test "retrieves value from params with string key" do
      schema =
        Zoi.object(%{
          name: Zoi.string()
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"name" => "John"})
      form = FormData.to_form(ctx, as: :user)

      assert FormData.input_value(ctx, form, :name) == "John"
      assert FormData.input_value(ctx, form, "name") == "John"
    end

    test "retrieves value from parsed when not in params" do
      schema =
        Zoi.object(%{
          age: Zoi.integer()
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"age" => "30"})

      # Create form without params
      form = %{FormData.to_form(ctx, as: :user) | params: %{}}

      # Should fall back to parsed data
      assert FormData.input_value(ctx, form, :age) == 30
    end

    test "retrieves value from input when not in params or parsed" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(10)
        })
        |> Zoi.Form.prepare()

      # Invalid input
      ctx = Zoi.Form.parse(schema, %{"name" => "Jo"})

      # Create form without params
      form = %{FormData.to_form(ctx, as: :user) | params: %{}}

      # Should fall back to input
      assert FormData.input_value(ctx, form, :name) == "Jo"
    end

    test "returns nil for missing fields" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.optional()
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{})
      form = FormData.to_form(ctx, as: :user)

      assert FormData.input_value(ctx, form, :missing) == nil
    end
  end

  describe "form errors" do
    test "hides errors when action is :ignore" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(5),
          email: Zoi.email()
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"name" => "Jo", "email" => "bad"})
      refute ctx.valid?

      form = FormData.to_form(ctx, as: :user, action: :ignore)
      assert form.errors == []
    end

    test "shows top-level errors" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(3)
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"name" => "Jo"})

      form = FormData.to_form(ctx, as: :user)
      assert {:name, _} = List.keyfind(form.errors, :name, 0)
    end

    test "handles base errors" do
      # This would require a schema that produces base-level errors
      # For now, just verify the error handling path exists
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})

      form = FormData.to_form(ctx, as: :user)
      # No base errors in this case
      refute List.keyfind(form.errors, :base, 0)
    end
  end

  describe "input_validations" do
    test "returns empty list" do
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})
      form = FormData.to_form(ctx, as: :user)

      # Zoi doesn't provide input validations (unlike Ecto)
      assert FormData.input_validations(ctx, form, :name) == []
    end
  end

  describe "name override" do
    test "uses custom name with :as option" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"tags" => ["a", "b"]})
      form = FormData.to_form(ctx, as: :post)

      # Override nested field name
      tag_forms = FormData.to_form(ctx, form, :tags, as: "custom_tags")
      assert List.first(tag_forms).name == "custom_tags[0]"
    end

    test "handles nil name" do
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})

      # Create form without :as
      form = FormData.to_form(ctx, [])
      assert form.name == nil
    end
  end

  describe "complex nested structures" do
    test "handles nested objects within arrays" do
      schema =
        Zoi.object(%{
          departments:
            Zoi.array(
              Zoi.object(%{
                name: Zoi.string(),
                budget: Zoi.integer(coerce: true)
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "departments" => [
          %{"name" => "Engineering", "budget" => "1000"},
          %{"name" => "Sales", "budget" => "2000"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      assert ctx.valid?

      form = FormData.to_form(ctx, as: :company)
      dept_forms = FormData.to_form(ctx, form, :departments, [])

      assert length(dept_forms) == 2
      assert [first, second] = dept_forms

      # Validated data is coerced
      assert first.data[:budget] == 1000
      assert second.data[:budget] == 2000

      # Input values preserved as strings
      assert FormData.input_value(ctx, first, :budget) == "1000"
      assert FormData.input_value(ctx, second, :budget) == "2000"
    end

    test "handles multiple levels of nesting" do
      schema =
        Zoi.object(%{
          user:
            Zoi.object(%{
              profile:
                Zoi.object(%{
                  age: Zoi.integer(coerce: true)
                })
            })
        })
        |> Zoi.Form.prepare()

      params = %{
        "user" => %{
          "profile" => %{
            "age" => "30"
          }
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      assert ctx.valid?

      form = FormData.to_form(ctx, as: :data)
      [user_form] = FormData.to_form(ctx, form, :user, [])
      [profile_form] = FormData.to_form(ctx, user_form, :profile, [])

      assert FormData.input_value(ctx, profile_form, :age) == "30"
      assert profile_form.data[:age] == 30
    end
  end

  describe "array field detection with Default wrapper" do
    test "detects array field wrapped in Default" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string()) |> Zoi.default([])
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"tags" => ["a", "b"]})
      form = FormData.to_form(ctx, as: :post)

      # Should recognize this as an array field
      tag_forms = FormData.to_form(ctx, form, :tags, [])
      assert is_list(tag_forms)
      assert length(tag_forms) == 2
    end

    test "detects nested Default wrappers around arrays" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.string()) |> Zoi.default([]) |> Zoi.default([])
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"items" => ["x"]})
      form = FormData.to_form(ctx, as: :data)

      item_forms = FormData.to_form(ctx, form, :items, [])
      assert is_list(item_forms)
      assert length(item_forms) == 1
    end
  end

  describe "map params with integer keys" do
    test "handles maps with integer keys in params" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{value: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      # Integer keys instead of string keys
      params = %{
        "items" => %{
          0 => %{"value" => "First"},
          1 => %{"value" => "Second"}
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :list)
      item_forms = FormData.to_form(ctx, form, :items, [])

      assert length(item_forms) == 2
      values = Enum.map(item_forms, &FormData.input_value(ctx, &1, :value))
      assert values == ["First", "Second"]
    end

    test "handles mixed integer and string numeric keys" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      params = %{
        "tags" => %{
          0 => "zero",
          "1" => "one",
          2 => "two"
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      form = FormData.to_form(ctx, as: :post)
      tag_forms = FormData.to_form(ctx, form, :tags, [])

      assert length(tag_forms) == 3
    end
  end

  describe "base-level errors in nested forms" do
    test "shows base errors for nested object" do
      schema =
        Zoi.object(%{
          profile: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      # Create context with base error on profile field
      ctx = Zoi.Form.parse(schema, %{"profile" => nil})
      refute ctx.valid?

      form = FormData.to_form(ctx, as: :user)
      [profile_form] = FormData.to_form(ctx, form, :profile, [])

      # Should have base error
      assert {:base, _} = List.keyfind(profile_form.errors, :base, 0)
    end

    test "shows base errors for array items" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{name: Zoi.string()}))
        })
        |> Zoi.Form.prepare()

      # Create item with base-level error
      ctx = Zoi.Form.parse(schema, %{"items" => [nil, %{"name" => "valid"}]})
      refute ctx.valid?

      form = FormData.to_form(ctx, as: :list)
      item_forms = FormData.to_form(ctx, form, :items, [])

      # First item should have base error
      [first_form | _] = item_forms
      assert {:base, _} = List.keyfind(first_form.errors, :base, 0)
    end
  end

  describe "ensure_map edge cases" do
    test "converts keyword list to map" do
      schema =
        Zoi.object(%{
          opts: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"opts" => %{"name" => "test"}})

      # Manually create context with keyword list in parsed data
      ctx_with_keyword = %{ctx | parsed: %{opts: [name: "test"]}}
      form = FormData.to_form(ctx_with_keyword, as: :config)

      [opts_form] = FormData.to_form(ctx_with_keyword, form, :opts, [])

      # Keyword list should be converted to map for form.data
      assert is_map(opts_form.data)
      assert opts_form.data[:name] == "test"
    end

    test "uses fallback for non-map non-keyword values" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{})

      # Create context with invalid data type
      ctx_invalid = %{ctx | parsed: %{user: "not a map"}}
      form = FormData.to_form(ctx_invalid, as: :data)

      [user_form] = FormData.to_form(ctx_invalid, form, :user, default: %{fallback: true})

      # Should use fallback
      assert user_form.data == %{fallback: true}
    end
  end

  describe "form id generation" do
    test "generates id from name by default" do
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})

      form = FormData.to_form(ctx, as: :user)
      assert form.id == "user"
    end

    test "accepts custom id" do
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})

      form = FormData.to_form(ctx, as: :user, id: "custom_id")
      assert form.id == "custom_id"
    end

    test "raises on non-binary id" do
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})

      assert_raise ArgumentError, ~r/:id option in form_for must be a binary/, fn ->
        FormData.to_form(ctx, as: :user, id: 123)
      end
    end

    test "uses name as fallback when id is nil" do
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})

      # When id is nil, it falls back to name
      form = FormData.to_form(ctx, as: :user, id: nil)
      assert form.id == "user"
    end

    test "allows nil id when name is also nil" do
      schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.Form.prepare()
      ctx = Zoi.Form.parse(schema, %{"name" => "test"})

      # Both id and name are nil
      form = FormData.to_form(ctx, id: nil)
      assert form.id == nil
    end
  end

  describe "nested form without parent name" do
    test "uses field name directly when parent has no name" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"tags" => ["a", "b"]})
      form = FormData.to_form(ctx, [])

      # Parent has no name
      assert form.name == nil

      tag_forms = FormData.to_form(ctx, form, :tags, [])

      # Should use just field name
      assert hd(tag_forms).name == "tags[0]"
    end
  end

  describe "error filtering" do
    test "filters errors by nested path correctly" do
      schema =
        Zoi.object(%{
          users:
            Zoi.array(
              Zoi.object(%{
                name: Zoi.string() |> Zoi.min(3),
                email: Zoi.email()
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "users" => [
          %{"name" => "Jo", "email" => "bad"},
          %{"name" => "Alice", "email" => "alice@example.com"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      refute ctx.valid?

      form = FormData.to_form(ctx, as: :company)
      [first_form, second_form] = FormData.to_form(ctx, form, :users, [])

      # First user should have errors
      assert length(first_form.errors) > 0

      # Second user should have no errors
      assert second_form.errors == []
    end

    test "filters out errors from other array indices" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{value: Zoi.integer(coerce: true)}))
        })
        |> Zoi.Form.prepare()

      params = %{
        "items" => [
          %{"value" => "100"},
          %{"value" => "bad"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)

      form = FormData.to_form(ctx, as: :list)
      [first, second] = FormData.to_form(ctx, form, :items, [])

      # Only second should have errors
      assert first.errors == []
      assert length(second.errors) > 0
    end

    test "handles errors with non-atom/non-string keys in path" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # Create context with errors at different path levels
      ctx = Zoi.Form.parse(schema, %{"items" => [123, 456]})

      form = FormData.to_form(ctx, as: :data)

      # Should handle errors gracefully
      assert is_list(form.errors)
    end
  end

  describe "data and params mismatch in nested forms" do
    test "handles data length greater than params length" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"tags" => ["a", "b", "c"]})

      # Manually create form with fewer params than data
      form = FormData.to_form(ctx, as: :post)
      form_with_less_params = %{form | params: %{"tags" => ["a"]}}

      # Should create forms for all items (max of data and params)
      tag_forms = FormData.to_form(ctx, form_with_less_params, :tags, [])
      assert length(tag_forms) == 3
    end

    test "handles params length greater than data length" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      # Parse with just one tag
      ctx = Zoi.Form.parse(schema, %{"tags" => ["a"]})

      # Manually create form with more params
      form = FormData.to_form(ctx, as: :post)
      form_with_more_params = %{form | params: %{"tags" => ["a", "b", "c"]}}

      # Should create forms for all items
      tag_forms = FormData.to_form(ctx, form_with_more_params, :tags, [])
      assert length(tag_forms) == 3
    end
  end

  describe "input_value with ctx.input field" do
    test "retrieves from ctx.input when not in params or parsed" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(10)
        })
        |> Zoi.Form.prepare()

      # Invalid input that won't be in parsed
      ctx = Zoi.Form.parse(schema, %{"name" => "short"})
      refute ctx.valid?

      # Create form without params to force fallback
      form = %{FormData.to_form(ctx, as: :user) | params: %{}}

      # Should fall back to ctx.input (which has the field)
      assert FormData.input_value(ctx, form, :name) == "short"
    end
  end

  describe "real-world form scenarios" do
    test "handles form submission with extra fields not in schema" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(3),
          email: Zoi.email()
        })
        |> Zoi.Form.prepare()

      # User submits form with CSRF token and other fields not in schema
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "_csrf_token" => "abc123",
        "submit" => "Save"
      }

      ctx = Zoi.Form.parse(schema, params)
      assert ctx.valid?
      assert ctx.parsed == %{name: "John Doe", email: "john@example.com"}

      # Extra fields should be in input but not in parsed
      assert ctx.input["_csrf_token"] == "abc123"
      assert ctx.input["submit"] == "Save"
    end

    test "handles complex e-commerce order form with nested validation errors" do
      schema =
        Zoi.object(%{
          customer:
            Zoi.object(%{
              name: Zoi.string() |> Zoi.min(3),
              email: Zoi.email(),
              phone: Zoi.string() |> Zoi.min(10)
            }),
          shipping_address:
            Zoi.object(%{
              street: Zoi.string() |> Zoi.min(5),
              city: Zoi.string() |> Zoi.min(2),
              zip: Zoi.string() |> Zoi.length(5)
            }),
          items:
            Zoi.array(
              Zoi.object(%{
                product_id: Zoi.string(),
                quantity: Zoi.integer() |> Zoi.min(1),
                price: Zoi.float() |> Zoi.min(0.01)
              })
            )
        })
        |> Zoi.Form.prepare()

      # Submit form with multiple validation errors at different nesting levels
      params = %{
        "customer" => %{
          "name" => "Jo",
          # Missing email
          "phone" => "123"
        },
        "shipping_address" => %{
          "street" => "St",
          "city" => "A",
          "zip" => "123"
        },
        "items" => [
          %{"product_id" => "PROD-1", "quantity" => "5", "price" => "29.99"},
          %{"product_id" => "PROD-2", "quantity" => "0", "price" => "-5.00"},
          %{"product_id" => "PROD-3", "quantity" => "invalid", "price" => "10.00"}
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      refute ctx.valid?

      form = FormData.to_form(ctx, as: :order)

      # Customer errors
      [customer_form] = FormData.to_form(ctx, form, :customer, [])
      assert {:name, _} = List.keyfind(customer_form.errors, :name, 0)
      assert {:phone, _} = List.keyfind(customer_form.errors, :phone, 0)

      # Shipping address errors
      [address_form] = FormData.to_form(ctx, form, :shipping_address, [])
      assert {:street, _} = List.keyfind(address_form.errors, :street, 0)
      assert {:city, _} = List.keyfind(address_form.errors, :city, 0)
      assert {:zip, _} = List.keyfind(address_form.errors, :zip, 0)

      # Item errors
      item_forms = FormData.to_form(ctx, form, :items, [])
      assert length(item_forms) == 3

      # First item valid
      assert Enum.at(item_forms, 0).errors == []

      # Second item has validation errors
      second_item = Enum.at(item_forms, 1)
      assert {:quantity, _} = List.keyfind(second_item.errors, :quantity, 0)
      assert {:price, _} = List.keyfind(second_item.errors, :price, 0)

      # Third item has coercion error
      third_item = Enum.at(item_forms, 2)
      assert {:quantity, _} = List.keyfind(third_item.errors, :quantity, 0)
    end

    test "handles partial form submission with optional fields" do
      schema =
        Zoi.object(%{
          name: Zoi.string() |> Zoi.min(3),
          email: Zoi.email(),
          phone: Zoi.string() |> Zoi.optional(),
          company: Zoi.string() |> Zoi.optional(),
          newsletter: Zoi.boolean() |> Zoi.optional()
        })
        |> Zoi.Form.prepare()

      # Submit only required fields
      params = %{
        "name" => "Jane Smith",
        "email" => "jane@example.com"
      }

      ctx = Zoi.Form.parse(schema, params)
      assert ctx.valid?
      assert ctx.parsed == %{name: "Jane Smith", email: "jane@example.com"}

      form = FormData.to_form(ctx, as: :user)

      # Optional fields should have nil values
      assert FormData.input_value(ctx, form, :phone) == nil
      assert FormData.input_value(ctx, form, :company) == nil
      assert FormData.input_value(ctx, form, :newsletter) == nil
    end

    test "handles blog post form with tags and categories" do
      schema =
        Zoi.object(%{
          title: Zoi.string() |> Zoi.min(5) |> Zoi.max(100),
          content: Zoi.string() |> Zoi.min(50),
          tags: Zoi.array(Zoi.string() |> Zoi.min(2)),
          category: Zoi.string(),
          published: Zoi.boolean()
        })
        |> Zoi.Form.prepare()

      params = %{
        "title" => "Introduction to Elixir Forms",
        "content" =>
          "This is a comprehensive guide to building forms in Phoenix LiveView using Zoi validation library...",
        "tags" => ["elixir", "phoenix", "forms", "liveview"],
        "category" => "tutorial",
        "published" => "true"
      }

      ctx = Zoi.Form.parse(schema, params)
      assert ctx.valid?

      form = FormData.to_form(ctx, as: :post)

      # Tags should be normalized to list
      assert form.params["tags"] == ["elixir", "phoenix", "forms", "liveview"]

      # Boolean should be coerced
      assert ctx.parsed.published == true
    end

    test "handles user profile form with progressive disclosure" do
      # Simulates a form where sections are shown/hidden based on user input
      schema =
        Zoi.object(%{
          account_type: Zoi.enum(["personal", "business"]),
          name: Zoi.string() |> Zoi.min(3),
          # Business-only fields (optional if personal)
          company_name: Zoi.string() |> Zoi.optional(),
          tax_id: Zoi.string() |> Zoi.optional(),
          # Contact info
          addresses:
            Zoi.array(
              Zoi.object(%{
                type: Zoi.enum(["home", "work", "billing"]),
                street: Zoi.string(),
                city: Zoi.string(),
                zip: Zoi.string()
              })
            )
        })
        |> Zoi.Form.prepare()

      # Business account with multiple addresses
      params = %{
        "account_type" => "business",
        "name" => "John Smith",
        "company_name" => "Smith Corp",
        "tax_id" => "12-3456789",
        "addresses" => %{
          "0" => %{
            "type" => "work",
            "street" => "123 Main St",
            "city" => "New York",
            "zip" => "10001"
          },
          "1" => %{
            "type" => "billing",
            "street" => "456 Oak Ave",
            "city" => "Boston",
            "zip" => "02101"
          }
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      assert ctx.valid?

      # Addresses should be normalized from map to list
      assert is_list(ctx.input["addresses"])
      assert length(ctx.input["addresses"]) == 2
      assert length(ctx.parsed.addresses) == 2

      form = FormData.to_form(ctx, as: :profile)
      address_forms = FormData.to_form(ctx, form, :addresses, [])
      assert length(address_forms) == 2

      # Verify address values are accessible
      assert FormData.input_value(ctx, Enum.at(address_forms, 0), :type) == "work"
      assert FormData.input_value(ctx, Enum.at(address_forms, 1), :type) == "billing"
    end
  end

  describe "action propagation to nested forms" do
    test "propagates action to nested forms" do
      schema =
        Zoi.object(%{
          addresses:
            Zoi.array(
              Zoi.object(%{
                street: Zoi.string() |> Zoi.min(5)
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{"addresses" => [%{"street" => "Hi"}]}
      ctx = Zoi.Form.parse(schema, params)

      # Create form with :validate action
      form = FormData.to_form(ctx, as: :user, action: :validate)
      [address_form] = FormData.to_form(ctx, form, :addresses, [])

      # Nested form should have the same action
      assert address_form.action == :validate

      # And should show errors
      assert {:street, _} = List.keyfind(address_form.errors, :street, 0)
    end

    test "propagates :ignore action to nested forms but errors still present" do
      schema =
        Zoi.object(%{
          items: Zoi.array(Zoi.object(%{name: Zoi.string() |> Zoi.min(5)}))
        })
        |> Zoi.Form.prepare()

      params = %{"items" => [%{"name" => "X"}]}
      ctx = Zoi.Form.parse(schema, params)

      # Create form with :ignore action
      form = FormData.to_form(ctx, as: :data, action: :ignore)
      [item_form] = FormData.to_form(ctx, form, :items, [])

      # Action is propagated
      assert item_form.action == :ignore

      # But nested forms still have errors (unlike top-level form)
      # This is expected behavior - :ignore only affects top-level form errors
      assert length(item_form.errors) > 0
    end
  end

  describe "edge cases in list_or_empty_maps with params" do
    test "handles params as empty map for array field" do
      schema =
        Zoi.object(%{
          tags: Zoi.array(Zoi.string())
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{})

      # Manually create form with empty map params for array field
      form = FormData.to_form(ctx, as: :post)
      form_with_empty = %{form | params: %{"tags" => %{}}}

      # Should return empty list
      tag_forms = FormData.to_form(ctx, form_with_empty, :tags, [])
      assert tag_forms == []
    end

    test "handles params with non-list value for non-array field" do
      schema =
        Zoi.object(%{
          user: Zoi.object(%{name: Zoi.string()})
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"user" => %{"name" => "test"}})
      form = FormData.to_form(ctx, as: :data)

      # This is a non-array field, should return single form
      [user_form] = FormData.to_form(ctx, form, :user, [])
      assert user_form.name == "data[user]"
    end
  end

  describe "nested object errors with deeper paths" do
    test "handles deeply nested validation errors" do
      schema =
        Zoi.object(%{
          user:
            Zoi.object(%{
              name: Zoi.string() |> Zoi.min(3),
              profile:
                Zoi.object(%{
                  age: Zoi.integer(coerce: true)
                })
            })
        })
        |> Zoi.Form.prepare()

      params = %{
        "user" => %{
          "name" => "Jo",
          "profile" => %{"age" => "invalid"}
        }
      }

      ctx = Zoi.Form.parse(schema, params)
      refute ctx.valid?

      # Just verify forms can be created without crashing
      form = FormData.to_form(ctx, as: :data)
      [user_form] = FormData.to_form(ctx, form, :user, [])

      # user_form should have errors for its direct fields
      assert {:name, _} = List.keyfind(user_form.errors, :name, 0)

      # Can create nested profile form
      profile_forms = FormData.to_form(ctx, user_form, :profile, [])
      assert is_list(profile_forms)
    end
  end

  describe "params with both string and atom keys" do
    test "prefers string key in params over atom key" do
      schema =
        Zoi.object(%{
          name: Zoi.string()
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"name" => "string_key"})

      # Manually create params with both string and atom keys
      form = FormData.to_form(ctx, as: :user)
      form_with_both = %{form | params: %{"name" => "string_value", name: "atom_value"}}

      # Should prefer string key
      assert FormData.input_value(ctx, form_with_both, :name) == "string_value"
    end
  end

  describe "non-standard field types" do
    test "handles field that is not in schema" do
      schema =
        Zoi.object(%{
          name: Zoi.string()
        })
        |> Zoi.Form.prepare()

      ctx = Zoi.Form.parse(schema, %{"name" => "test"})
      form = FormData.to_form(ctx, as: :user)

      # Access field not in schema - this won't be an array
      other_forms = FormData.to_form(ctx, form, :other_field, [])

      # Should return single empty form
      assert length(other_forms) == 1
    end
  end

  describe "error paths with numeric indices" do
    test "handles deeply nested array structures with errors" do
      schema =
        Zoi.object(%{
          departments:
            Zoi.array(
              Zoi.object(%{
                name: Zoi.string(),
                teams: Zoi.array(Zoi.object(%{name: Zoi.string() |> Zoi.min(3)}))
              })
            )
        })
        |> Zoi.Form.prepare()

      params = %{
        "departments" => [
          %{
            "name" => "Engineering",
            "teams" => [
              %{"name" => "Backend"},
              %{"name" => "X"}
            ]
          }
        ]
      }

      ctx = Zoi.Form.parse(schema, params)
      refute ctx.valid?

      # Verify forms can be created for nested structures
      form = FormData.to_form(ctx, as: :company)
      dept_forms = FormData.to_form(ctx, form, :departments, [])
      assert length(dept_forms) > 0

      # Can access nested teams
      first_dept = List.first(dept_forms)
      team_forms = FormData.to_form(ctx, first_dept, :teams, [])
      assert is_list(team_forms)
    end
  end
end
