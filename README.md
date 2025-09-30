# Zoi

<img src="https://github.com/phcurado/zoi/raw/main/guides/images/logo.png" alt="Zoi" width="150">

[![CI](https://github.com/phcurado/zoi/actions/workflows/ci.yml/badge.svg)](https://github.com/phcurado/zoi/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/phcurado/zoi/badge.svg?branch=main)](https://coveralls.io/github/phcurado/zoi?branch=main)
[![Hex.pm](https://img.shields.io/hexpm/v/zoi)](https://hex.pm/packages/zoi)
[![HexDocs.pm](https://img.shields.io/badge/Docs-HexDocs-blue)](https://hexdocs.pm/zoi)
[![License](https://img.shields.io/hexpm/l/zoi.svg)](https://hex.pm/packages/zoi)

---

<a href='https://ko-fi.com/R5R11AIF9P' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

`Zoi` is a schema validation library for Elixir, designed to provide a simple and flexible way to define and validate data.

## Installation

`zoi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoi, "~> 0.6"}
  ]
end
```

## Usage

You can create schemas for various data types, including strings, integers, floats, booleans, arrays, maps, and more. `Zoi` supports a wide range of validation rules and transformations.

### Parsing Data

Here's a simple example of how to use `Zoi` to validate a string:

```elixir
# Define a schema with a string type
iex> schema = Zoi.string() |> Zoi.min(3)
iex> Zoi.parse(schema, "hello")
{:ok, "hello"}
iex> Zoi.parse(schema, "hi")
{:error, [%Zoi.Error{message: "too small: must have at least 3 characters"}]}


# Add transforms to a schema
iex> schema = Zoi.string() |> Zoi.trim()
iex> Zoi.parse(schema, "    world    ")
{:ok, "world"}
```

You can also validate structured maps:

```elixir
# Validate a structured data in a map
iex> schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer(), email: Zoi.email()})
iex> Zoi.parse(schema, %{name: "John", age: 30, email: "john@email.com"})
{:ok, %{name: "John", age: 30, email: "john@email.com"}}
iex> Zoi.parse(schema, %{email: "invalid-email"})
{:error, [
    %Zoi.Error{path: [:name], message: "is required"},
    %Zoi.Error{path: [:age], message: "is required"},
    %Zoi.Error{path: [:email], message: "invalid email format"}
]}
```

and arrays:

```elixir
# Validate an array of integers
iex> schema = Zoi.array(Zoi.integer() |> Zoi.min(0)) |> Zoi.min(2)
iex> Zoi.parse(schema, [1, 2, 3])
{:ok, [1, 2, 3]}
iex> Zoi.parse(schema, [1, "2"])
{:error, [%Zoi.Error{path: [1], message: "invalid type: must be an integer"}]}
```

And many more possibilities, including nested schemas, custom validations and data transformations. Check the official [docs](https://hexdocs.pm/zoi) for more details.

## Types

`Zoi` can infer types from schemas, allowing you to leverage Elixir's `@type` and `@spec` annotations for documentation

```elixir
defmodule MyApp.Schema do
    @schema Zoi.string() |> Zoi.min(2) |> Zoi.max(100)
    @type t :: unquote(Zoi.type_spec(@schema))
end
```

This will generate the following type specification:

```elixir
@type t :: binary()
```

This also applies to complex types, such as `Zoi.object/2`:

```elixir
defmodule MyApp.User do
    @schema Zoi.object(%{
        name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
        age: Zoi.integer() |> Zoi.optional(),
        email: Zoi.email()
    })
    @type t :: unquote(Zoi.type_spec(@schema))
end
```

Which will generate:

```elixir
@type t :: %{
    required(:name) => binary(),
    optional(:age) => integer(),
    required(:email) => binary()
}
```

### Errors

When validation fails, `Zoi` returns a list of errors, each containing a message and the path to the invalid data. Even when erros are nested, `Zoi` will return all errors in a flattened list.

```elixir
iex> schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})
iex> Zoi.parse(schema, %{name: 123, age: "thirty"})
{:error, [
    %Zoi.Error{path: [:name], message: "invalid type: must be a string"},
    %Zoi.Error{path: [:age], message: "invalid type: must be an integer"}
]}
```

You can view the error in a map format using the `Zoi.treefy_errors/1` function:

```elixir
iex> Zoi.treefy_errors(errors)
%{
    name: ["invalid type: must be a string"],
    age: ["invalid type: must be an integer"]
}
```

You can also customize error messages using the `Zoi.message/2` function:

```elixir
iex> schema = Zoi.string(error: "Min of 3 characters") |> Zoi.min(3)
iex> Zoi.parse(schema, "hi")
{:error, [%Zoi.Error{message: "Min of 3 characters"}]}
```

## Acknowledgements

`Zoi` is inspired by [Zod](https://zod.dev/) and [Joi](https://joi.dev/), providing a similar experience for Elixir.
