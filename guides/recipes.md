# Recipes

- [Using `Zoi.object/2` with string or atom keys](#using-zoijobject2-with-string-or-atom-keys)
- [Applying coercion globally in the schema](#applying-coercion-globally-in-the-schema)
- [Applying nullable or nullish or optional globally in the schema](#applying-nullable-or-nullish-or-optional-globally-in-the-schema)
- [Generalizing types](#generalizing-types)
- [Creating a user registration schema](#creating-a-user-registration-schema)

## Using `Zoi.object/2` with string or atom keys

When defining object schemas with `Zoi.object/2`, you can use either string keys or atom keys for the fields. Both approaches are supported but differ on how parsing will work:

```elixir
# Using atom keys
schema = Zoi.object(%{
  name: Zoi.string(),
  age: Zoi.integer()
})
# Parsing with atom keys
Zoi.parse(schema, %{name: "Alice", age: 30})
# => {:ok, %{name: "Alice", age: 30}}
# Parsing with string keys will fail
Zoi.parse(schema, %{"name" => "Alice", "age" => 30})
# => {:error,
# =>  [
# =>    %Zoi.Error{
# =>      code: :required,
# =>      issue: {"is required", [key: :name]},
# =>      message: "is required",
# =>      path: [:name]
# =>    },
# =>    %Zoi.Error{
# =>      code: :required,
# =>      issue: {"is required", [key: :age]},
# =>      message: "is required",
# =>      path: [:age]
# =>    }
# =>  ]}
```

If you want to parse data with string keys, you can define the schema with string keys:

```elixir
# Using string keys
schema = Zoi.object(%{
  "name" => Zoi.string(),
  "age" => Zoi.integer()
})
# Parsing with string keys
Zoi.parse(schema, %{"name" => "Alice", "age" => 30})
# => {:ok, %{"name" => "Alice", "age" => 30}}
```

Alternatively, you may choose to allow your schema to process either string or atom keys when declaring the schema with atom keys. This can be done using the `coerce: true` option. Considering the first schema defined with atom keys:

```elixir
Zoi.parse(schema, %{"name" => "Alice", "age" => 30}, coerce: true)
# => {:ok, %{name: "Alice", age: 30}}
```

## Applying coercion globally in the schema

It can be a tedious task to add the `coerce: true` in every type in your schema. To simplify this, you can apply a traverse function that sets the `coerce: true` option for all types in your schema. Here's how you can do it:

```elixir
schema = Zoi.object(%{
  name: Zoi.string(),
  age: Zoi.integer(),
  address: Zoi.object(%{
    street: Zoi.string(),
    city: Zoi.string()
  })
}) |> Zoi.Schema.traverse(&Zoi.coerce/1)
```

This will make all fields in the schema to coerce to it's declared type.

## Applying nullable or nullish or optional globally in the schema

Similar to coercion, you can apply any transformation into the traverse function:

```elixir
schema = Zoi.object(%{
  name: Zoi.string(),
  age: Zoi.integer()
}) |> Zoi.Schema.traverse(fn node ->
  node
  |> Zoi.nullable()
  |> Zoi.optional()
end)
```

## Generalizing types

In your application, you might have multiple schemas that share common fields. Instead of redefining these fields in each schema, you can create a generalized type and reuse it across different schemas. Since `Zoi` types are just functions, you can define a function that returns a schema and use it wherever needed.

```elixir
defmodule MyApp.ZoiTypes do

  def user_info() do
    Zoi.object(%{
      name: Zoi.string(description: "user full name"),
      email: Zoi.email(description: "user email address")
    })
  end

  def supported_currencies() do
    Zoi.enum(["USD", "EUR", "GBP", "JPY"], description: "supported currency codes")
  end

   # For example, converting ecto enums to zoi enums
  def user_types() do
    Zoi.enum(Ecto.Enum.mappings(MyApp.Accounts.User, :type),
      description: "User types"
    )
  end
end
```

## Creating a user registration schema

Common example is having a user registration schema, that requires a valid email address and password with confirmation.

```elixir
schema = Zoi.object(%{
  email: Zoi.email(description: "User email address"),
  password: Zoi.string() |> Zoi.min(8),
  password_confirmation: Zoi.string()
}) |> Zoi.refine(fn data ->
  if data.password == data.password_confirmation do
    :ok
  else
    {:error, "Password confirmation does not match"}
  end
end)
Zoi.parse(schema, %{
  email: "john@example.com",
  password: "securepassword",
  password_confirmation: "hello"
})
# => {:error,
# =>  [
# =>    %Zoi.Error{
# =>      code: :custom,
# =>      issue: {"Password confirmation does not match", []},
# =>      message: "Password confirmation does not match",
# =>      path: []
# =>    }
# =>  ]}
```
