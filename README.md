# Zoi

[![CI](https://github.com/phcurado/zoi/actions/workflows/ci.yml/badge.svg)](https://github.com/phcurado/zoi/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/phcurado/zoi/badge.svg?branch=main)](https://coveralls.io/github/phcurado/zoi?branch=main)
[![Hex.pm](https://img.shields.io/hexpm/v/zoi)](https://hex.pm/packages/zoi)
[![HexDocs.pm](https://img.shields.io/badge/Docs-HexDocs-blue)](https://hexdocs.pm/zoi)
[![License](https://img.shields.io/hexpm/l/zoi.svg)](https://hex.pm/packages/zoi)

`Zoi` is a schema validation library for Elixir, designed to provide a simple and flexible way to define and validate data.

## Installation

`zoi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoi, "~> 0.2"}
  ]
end
```

## Usage

You can define schemas and validate data against them. Schemas can be used to validate maps, lists or primitive types such as strings, integers, etc.

```elixir
# Define a schema with primitive type
schema = Zoi.string() |> Zoi.min(3)
Zoi.parse(schema, "hello") # {:ok, "hello"}

schema = Zoi.string() |> Zoi.trim()
Zoi.parse(schema, "    world    ") # {:ok, "world"}

# Validate a structured data in a map
schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer(), email: Zoi.email()})
Zoi.parse(schema, %{name: "John", age: 30, email: "john@email.com"})
# {:ok, %{name: "John", age: 30, email: "john@email.com"}}

Zoi.parse(schema, %{email: "invalid-email"})
#{:error, [
#          %Zoi.Error{path: [:name], message: "is required"},
#          %Zoi.Error{path: [:age], message: "is required"},
#          %Zoi.Error{path: [:email], message: "invalid email format"}
#         ]
#}

```

And many more possibilities, including nested schemas, custom validations and data transformations. Check the official [docs](https://hexdocs.pm/zoi) for more details.

## Acknowledgements

`Zoi` is inspired by [Zod](https://zod.dev/) and [Joi](https://joi.dev/), providing a similar experience for Elixir.
