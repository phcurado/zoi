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
end
