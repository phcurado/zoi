defmodule Zoi.FormDataTest do
  use ExUnit.Case, async: true

  alias Phoenix.HTML.FormData

  defp profile_schema do
    Zoi.object(%{
      name: Zoi.string() |> Zoi.min(3),
      profile:
        Zoi.object(%{
          bio: Zoi.string() |> Zoi.max(100)
        })
    })
    |> Zoi.Form.prepare()
  end

  test "keeps params when validations fail" do
    params = %{"name" => "Jo", "profile" => %{"bio" => "Hello"}}

    context = Zoi.Form.parse(profile_schema(), params)

    refute context.valid?
    assert context.input == params

    form = FormData.to_form(context, as: :user)

    assert form.name == "user"
    assert form.params == params

    assert {:name, {"too small: must have at least %{count} character(s)", [count: 3]}} in form.errors

    assert FormData.input_value(context, form, :name) == "Jo"

    [profile_form] = FormData.to_form(context, form, :profile, [])
    assert FormData.input_value(context, profile_form, :bio) == "Hello"
  end

  test "builds nested forms for arrays of objects" do
    schema =
      Zoi.object(%{
        addresses:
          Zoi.array(
            Zoi.object(%{
              line1: Zoi.string() |> Zoi.min(1),
              city: Zoi.string()
            })
          )
      })
      |> Zoi.Form.prepare()

    params = %{
      "addresses" => [
        %{"line1" => "Main", "city" => "Lisbon"},
        %{"line1" => "Second", "city" => "Porto"}
      ]
    }

    context = Zoi.Form.parse(schema, params)

    form = FormData.to_form(context, as: :company)
    address_forms = FormData.to_form(context, form, :addresses, [])

    assert length(address_forms) == 2

    assert Enum.map(address_forms, &FormData.input_value(context, &1, :line1)) == [
             "Main",
             "Second"
           ]

    assert Enum.map(address_forms, &FormData.input_value(context, &1, :city)) == [
             "Lisbon",
             "Porto"
           ]
  end

  test "preserves parsed values for valid entries when siblings fail" do
    schema =
      Zoi.object(%{
        addresses:
          Zoi.array(
            Zoi.object(%{
              line1: Zoi.string() |> Zoi.min(2),
              postal_code: Zoi.integer(coerce: true)
            })
          )
      })
      |> Zoi.Form.prepare()

    params = %{
      "addresses" => [
        %{"line1" => "Main", "postal_code" => "1000"},
        %{"line1" => "X", "postal_code" => "oops"}
      ]
    }

    context = Zoi.Form.parse(schema, params)
    refute context.valid?

    assert context.parsed[:addresses] == [%{line1: "Main", postal_code: 1000}]

    form = FormData.to_form(context, as: :company)
    [first_form, second_form] = FormData.to_form(context, form, :addresses, [])

    assert first_form.data[:postal_code] == 1000
    assert FormData.input_value(context, second_form, :postal_code) == "oops"
  end

  test "normalizes LiveView maps with metadata into arrays" do
    schema =
      Zoi.object(%{
        addresses:
          Zoi.array(
            Zoi.object(%{
              label: Zoi.string(),
              street: Zoi.string(),
              zip: Zoi.integer(coerce: true)
            })
          )
      })
      |> Zoi.Form.prepare()

    params = %{
      "_target" => ["user", "profile", "name"],
      "addresses" => %{
        "_persistent_id" => "0",
        "_unused_label" => "",
        "_unused_street" => "",
        "_unused_zip" => "",
        "label" => "Home",
        "street" => "Main",
        "zip" => "1000"
      }
    }

    context = Zoi.Form.parse(schema, params)
    form = FormData.to_form(context, as: :user)
    [address_form] = FormData.to_form(context, form, :addresses, [])

    assert FormData.input_value(context, address_form, :label) == "Home"
    assert FormData.input_value(context, address_form, :street) == "Main"
    assert FormData.input_value(context, address_form, :zip) == "1000"
    assert get_in(form.params, ["_target"]) == ["user", "profile", "name"]

    assert form.params["addresses"] == %{
             "_persistent_id" => "0",
             "_unused_label" => "",
             "_unused_street" => "",
             "_unused_zip" => "",
             "label" => "Home",
             "street" => "Main",
             "zip" => "1000"
           }
  end

  test "preserves entry order when LiveView sends maps with numeric keys" do
    schema =
      Zoi.object(%{
        addresses:
          Zoi.array(
            Zoi.object(%{
              label: Zoi.string()
            })
          )
      })
      |> Zoi.Form.prepare()

    params = %{
      "addresses" => %{
        "_persistent_id" => "ignored",
        "1" => %{"label" => "Work"},
        "0" => %{"label" => "Home"}
      }
    }

    context = Zoi.Form.parse(schema, params)

    form = FormData.to_form(context, as: :company)
    address_forms = FormData.to_form(context, form, :addresses, [])

    assert Enum.map(address_forms, &FormData.input_value(context, &1, :label)) == [
             "Home",
             "Work"
           ]
  end

  test "keeps Phoenix helper params but still exposes nested values" do
    schema =
      Zoi.object(%{
        tags: Zoi.array(Zoi.object(%{label: Zoi.string()}))
      })
      |> Zoi.Form.prepare()

    params = %{
      "tags" => %{
        "_persistent_id" => "0",
        "_unused_label" => "",
        "label" => "Urgent"
      }
    }

    context = Zoi.Form.parse(schema, params)
    form = FormData.to_form(context, as: :task)
    [tag_form] = FormData.to_form(context, form, :tags, [])

    assert FormData.input_value(context, tag_form, :label) == "Urgent"

    assert form.params["tags"] == %{
             "_persistent_id" => "0",
             "_unused_label" => "",
             "label" => "Urgent"
           }
  end
end
