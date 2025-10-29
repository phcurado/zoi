# Quickstart Guide

This guide will help you get started with `Zoi` on your Elixir project.

## Installation

Add `zoi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoi, "~> 0.8"}
  ]
end
```

## Defining Schemas

You can define schemas using a variety of built-in types and validation rules. Here are some examples:

```elixir
# String schema with minimum length
schema = Zoi.string() |> Zoi.min(3)
# Integer schema with range
schema = Zoi.integer() |> Zoi.min(1) |> Zoi.max(100)
# Email schema
schema = Zoi.email()
# Object schema with nested fields
schema = Zoi.object(%{
  name: Zoi.string() |> Zoi.regex(~r/^[a-zA-Z ]+$/),
  age: Zoi.integer() |> Zoi.min(0),
  email: Zoi.email()
})
# Array schema with item validation
schema = Zoi.array(Zoi.integer() |> Zoi.min(0)) |> Zoi.min(2)
```

## Validating Data

You can validate data against your defined schemas using the `Zoi.parse/2` function:

```elixir
schema = Zoi.object(%{
  name: Zoi.string() |> Zoi.regex(~r/^[a-zA-Z ]+$/),
  age: Zoi.integer() |> Zoi.min(0),
  email: Zoi.email()
})

Zoi.parse(schema, %{name: "John Doe", age: 30, email: "john@email.com"})
# {:ok, %{name: "John Doe", age: 30, email: "john@email.com"}}

Zoi.parse(schema, %{name: "John123", age: -5, email: "invalid-email"})
# {:error, [
#   %Zoi.Error{path: [:name], message: "invalid string: must match a pattern ~r/^[a-zA-Z ]+$/"},
#   %Zoi.Error{path: [:age], message: "too small: must be at least 0"},
#   %Zoi.Error{path: [:email], message: "invalid email format"}
# ]}
```

## Use Cases

You can use `Zoi` in various scenarios, such as:

- Validating user input in web forms
- Validating API request parameters
- Normalizing data before processing
- Generating OpenAPI specifications
- Integrating with external systems and validating responses
- And more!

Check out the other guides and the documentation for more advanced usage and features!
