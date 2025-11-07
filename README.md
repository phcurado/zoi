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
    {:zoi, "~> 0.9"}
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
{:error,
 [
   %Zoi.Error{
     code: :greater_than_or_equal_to,
     issue: {"too small: must have at least %{count} character(s)", [count: 3]},
     message: "too small: must have at least 3 character(s)",
     path: []
   }
 ]}


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
iex> {:error, errors} = Zoi.parse(schema, %{email: "invalid-email"})
iex> Zoi.treefy_errors(errors)
%{name: ["is required"], email: ["invalid email format"], age: ["is required"]}
```

or arrays:

```elixir
# Validate an array of integers
iex> schema = Zoi.array(Zoi.integer() |> Zoi.min(0)) |> Zoi.min(2)
iex> Zoi.parse(schema, [1, 2, 3])
{:ok, [1, 2, 3]}
iex> Zoi.parse(schema, [1, "2"])
{:error,
 [
   %Zoi.Error{
     code: :invalid_type,
     issue: {"invalid type: expected integer", [type: :integer]},
     message: "invalid type: expected integer",
     path: [1]
   }
 ]}
```

keywords:

```elixir
# Validate a keyword list
iex> schema = Zoi.keyword(email: Zoi.email(), allow?: Zoi.boolean())
iex> Zoi.parse(schema, [email: "john@email.com", allow?: true])
{:ok, [email: "john@email.com", allow?: true]}
iex> Zoi.parse(schema, [allow?: "yes"])
{:error,
 [
   %Zoi.Error{
     code: :invalid_type,
     issue: {"invalid type: expected boolean", [type: :boolean]},
     message: "invalid type: expected boolean",
     path: [:allow?]
   }
 ]}
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
{:error,
 [
   %Zoi.Error{
     code: :invalid_type,
     issue: {"invalid type: expected string", [type: :string]},
     message: "invalid type: expected string",
     path: [:name]
   },
   %Zoi.Error{
     code: :invalid_type,
     issue: {"invalid type: expected integer", [type: :integer]},
     message: "invalid type: expected integer",
     path: [:age]
   }
 ]}
```

You can view the error in a map format using the `Zoi.treefy_errors/1` function:

```elixir

iex> schema = Zoi.object(%{name: Zoi.string(), age: Zoi.integer()})
iex> {:error, errors} = Zoi.parse(schema, %{name: 123, age: "thirty"})
iex> Zoi.treefy_errors(errors)
%{
  name: ["invalid type: expected string"],
  age: ["invalid type: expected integer"]
}
```

You can also customize error messages:

```elixir
iex> schema = Zoi.string(error: "not a string")
iex> Zoi.parse(schema, :hi)
{:error,
 [
   %Zoi.Error{
     code: :custom,
     issue: {"not a string", [type: :string]},
     message: "not a string",
     path: []
   }
 ]}
```

## Phoenix forms

`Zoi` implements the `Phoenix.HTML.FormData` protocol for `Zoi.Context`, enabling direct use
with `Phoenix.Component.to_form/2` or other Phoenix HTML form helpers.

1. Add the optional dependency to your `mix.exs`:

   ```elixir
   {:phoenix_html, "~> 2.14.2 or ~> 3.0 or ~> 4.1"}
   ```

2. Build your schema as an object and enhance it for forms:

   ```elixir
   defmodule MyApp.Accounts.UserSchema do
     @schema \
       Zoi.object(%{
         name: Zoi.string() |> Zoi.min(3),
         email: Zoi.email(),
         age: Zoi.integer() |> Zoi.optional(),
         addresses:
           Zoi.array(
             Zoi.object(%{
               line1: Zoi.string() |> Zoi.min(3),
               city: Zoi.string()
             })
           )
       })
       |> Zoi.Form.enhance()

     def schema, do: @schema
   end
   ```

   `Zoi.Form.enhance/1` enables key coercion, flips `:coerce` on every field (so strings get
   cast into integers/booleans/etc.), and treats `nil`/`""` as empty values across the whole
   schema tree, matching what Phoenix forms send.

3. Parse params with `Zoi.Form.parse/3` and turn the context into a form:

   ```elixir
   def create(assigns) do
     context =
       assigns.params
       |> Zoi.Form.parse(MyApp.Accounts.UserSchema.schema())

     assigns = assign(assigns, :form, Phoenix.Component.to_form(context, as: :user))
     ~H"""
     <.form for={@form} phx-submit="save">
       <.input field={@form[:name]} label="Name" />
       <.inputs_for :let={address} field={@form[:addresses]}>
         <.input field={address[:line1]} label="Address" />
       </.inputs_for>
     </.form>
     """
   end
   ```

`context.valid?` mirrors success or failure, while `context.errors` are exposed through
`form.errors`. Because the context stores both the original params (`context.input`) and the
successfully parsed data (`context.parsed`), forms keep all submitted values—even partial data
when some fields fail validation.

👉 See the full **[Rendering forms with Phoenix](guides/rendering_forms_with_phoenix.md)** guide for
a larger example, including nested collections and submit handling. To localize error messages,
check **[Localizing Zoi errors with Gettext](guides/localizing_errors_with_gettext.md)**.

### Metadata

`Zoi` supports 3 types of metadata:

- `description`: Description of the schema.
- `example`: An example value that conforms to the schema.
- `metadata`: A keyword list of arbitrary metadata.

You can use in all types, for example:

```elixir
iex> schema = Zoi.string(description: "Hello", example: "World!", metadata: [identifier: "string"])
iex> Zoi.description(schema)
"Hello"
iex> Zoi.example(schema)
"World!"
iex> Zoi.metadata(schema)
[identifier: "string"]
```

You can use this feature to create self-documenting schemas, with example and tests. For example:

```elixir
defmodule MyApp.UserSchema do
  @schema Zoi.object(
            %{
            name: Zoi.string(description: "The user first name") |> Zoi.min(2) |> Zoi.max(100),
            age: Zoi.integer(description: "The user age") |> Zoi.optional()
            },
            description: "A user schema with name and optional age",
            example: %{name: "Alice", age: 30},
            metadata: [
              moduledoc: "This module represents a schema of a user"
            ]
          )

  @moduledoc """
  #{Zoi.metadata(@schema)[:moduledoc]}
  """

  @doc """
  #{Zoi.description(@schema)}

  Options:

  #{Zoi.describe(@schema)}
  """
  def schema, do: @schema
end

defmodule MyApp.UserSchemaTest do
  use ExUnit.Case
  alias MyApp.UserSchema

  test "example matches schema" do
    example = Zoi.example(UserSchema.schema())
    assert {:ok, example} == Zoi.parse(UserSchema.schema(), example)
  end
end
```

`description`, `example` are also used when generating OpenAPI specs. See the [Using Zoi to generate OpenAPI specs](https://hexdocs.pm/zoi/using_zoi_to_generate_openapi_specs.html) guide for more details.

## Guides

Check the official guides for more examples and use cases:

- [Quickstart Guide](https://hexdocs.pm/zoi/quickstart_guide.html)
- [Main API Reference](https://hexdocs.pm/zoi/Zoi.html)
- [Using Zoi to generate OpenAPI specs](https://hexdocs.pm/zoi/using_zoi_to_generate_openapi_specs.html)
- [Validating controller parameters](https://hexdocs.pm/zoi/validating_controller_parameters.html)
- [Converting Keys From Object](https://hexdocs.pm/zoi/converting_keys_from_object.html)
- [Generating Schemas from JSON](https://hexdocs.pm/zoi/generating_schemas_from_json_example.html)

## Acknowledgements

`Zoi` is inspired by [Zod](https://zod.dev/) and [Joi](https://joi.dev/), providing a similar experience for Elixir.
