# Recipes

- [Using `Zoi.map/2` with string or atom keys](#using-zoijobject2-with-string-or-atom-keys)
- [Applying coercion globally in the schema](#applying-coercion-globally-in-the-schema)
- [Applying nullable or nullish or optional globally in the schema](#applying-nullable-or-nullish-or-optional-globally-in-the-schema)
- [Generalizing types](#generalizing-types)
- [Custom error messages](#custom-error-messages)
- [Conditional fields](#conditional-fields)
- [Creating a user registration schema](#creating-a-user-registration-schema)

## Using `Zoi.map/2` with string or atom keys

When defining object schemas with `Zoi.map/2`, you can use either string keys or atom keys for the fields. Both approaches are supported but differ in how parsing will work:

```elixir
# Using atom keys
schema = Zoi.map(%{
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
schema = Zoi.map(%{
  "name" => Zoi.string(),
  "age" => Zoi.integer()
})

# Parsing with string keys
Zoi.parse(schema, %{"name" => "Alice", "age" => 30})
# => {:ok, %{"name" => "Alice", "age" => 30}}
```

Alternatively, you may choose to allow your schema to process either string or atom keys when declaring the schema with atom keys. This can be done using the `coerce: true` option. Considering the first schema defined with atom keys:

```elixir
schema = Zoi.map(%{
  name: Zoi.string(),
  age: Zoi.integer()
}, coerce: true)

# Parsing with string keys
Zoi.parse(schema, %{"name" => "Alice", "age" => 30})
# => {:ok, %{name: "Alice", age: 30}}
```

## Applying coercion globally in the schema

It can be a tedious task to add the `coerce: true` in every type in your schema. To simplify this, you can apply a traverse function that sets the `coerce: true` option for all types in your schema. Here's how you can do it:

```elixir
schema = Zoi.map(%{
  name: Zoi.string(),
  age: Zoi.integer(),
  address: Zoi.map(%{
    street: Zoi.string(),
    city: Zoi.string()
  })
}) |> Zoi.Schema.traverse(&Zoi.coerce/1)
```

This will make all fields in the schema to coerce to its declared type.

## Applying nullable or nullish or optional globally in the schema

Similar to coercion, you can apply any transformation into the traverse function:

```elixir
schema = Zoi.map(%{
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
    Zoi.map(%{
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

# Using the generalized types in your schemas
schema = Zoi.map(%{
  user: MyApp.ZoiTypes.user_info(),
  prefered_currency: MyApp.ZoiTypes.supported_currencies(),
  user_type: MyApp.ZoiTypes.user_types()
})

Zoi.parse(schema, %{
  user: %{name: "Alice", email: "alice@example.com"},
  prefered_currency: "USD",
  user_type: :admin
})
# => {:ok, %{user: %{name: "Alice", email: "alice@example.com"}, prefered_currency: "USD", user_type: :admin}}
```

## Custom error messages

You can provide custom error messages for your validations using the `refine` function. This is useful when you want to give more specific feedback to users based on business logic.

```elixir
schema = Zoi.map(%{
  age: Zoi.integer()
}) |> Zoi.refine(fn data ->
  if data.age >= 18 do
    :ok
  else
    {:error, "You must be at least 18 years old to register"}
  end
end)

Zoi.parse(schema, %{age: 16})
# => {:error,
# =>  [
# =>    %Zoi.Error{
# =>      code: :custom,
# =>      issue: {"You must be at least 18 years old to register", []},
# =>      message: "You must be at least 18 years old to register",
# =>      path: []
# =>    }
# =>  ]}

Zoi.parse(schema, %{age: 21})
# => {:ok, %{age: 21}}
```

You can also target specific fields in your error messages by using the `path` option:

```elixir
schema = Zoi.map(%{
  username: Zoi.string()
}) |> Zoi.refine(fn data ->
  if String.contains?(data.username, " ") do
    {:error, [%Zoi.Error{
      code: :custom,
      message: "Username cannot contain spaces",
      path: [:username],
      issue: {"Username cannot contain spaces", []}
    }]}
  else
    :ok
  end
end)

Zoi.parse(schema, %{username: "john doe"})
# => {:error,
# =>  [
# =>    %Zoi.Error{
# =>      code: :custom,
# =>      issue: {"Username cannot contain spaces", []},
# =>      message: "Username cannot contain spaces",
# =>      path: [:username]
# =>    }
# =>  ]}
```

## Conditional fields

You can use `refine` to require fields only when another field has a specific value.

```elixir
schema = Zoi.map(%{
  account_type: Zoi.enum(["personal", "business"]),
  company_name: Zoi.string() |> Zoi.optional(),
  tax_id: Zoi.string() |> Zoi.optional()
})|> Zoi.refine(fn data ->
  cond do
    data[:account_type] == "business" and !data[:company_name] ->
      {:error, "Company name and Tax ID are required for business accounts"}
    data[:account_type] == "business" and !data[:tax_id] ->
      {:error, "Company name and Tax ID are required for business accounts"}
    true ->
      :ok
  end
end)

Zoi.parse(schema, %{account_type: "business"})
# => {:error,
# =>  [
# =>    %Zoi.Error{
# =>      code: :custom,
# =>      issue: {"Company name and Tax ID are required for business accounts", []},
# =>      message: "Company name and Tax ID are required for business accounts",
# =>      path: []
# =>    }
# =>  ]}

Zoi.parse(schema, %{account_type: "personal"})
# => {:ok, %{account_type: "personal"}}

Zoi.parse(schema, %{account_type: "business", company_name: "Acme Corp", tax_id: "123456789"})
# => {:ok, %{account_type: "business", company_name: "Acme Corp", tax_id: "123456789"}}
```

## Creating a user registration schema

Common example is having a user registration schema, that requires a valid email address and password with confirmation.

```elixir
schema = Zoi.map(%{
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

Zoi.parse(schema, %{
  email: "john@example.com",
  password: "securepassword",
  password_confirmation: "securepassword"
})
# => {:ok, %{email: "john@example.com", password: "securepassword", password_confirmation: "securepassword"}}
```
