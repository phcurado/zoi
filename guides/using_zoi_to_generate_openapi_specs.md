# Using Zoi to generate OpenAPI specs

The OpenAPI Specification define a standard interface for HTTP APIs. It uses the [JSON Schema](https://json-schema.org) specification to describe the structure of request and response payloads.
`Zoi` implements the conversion between `Zoi` schemas and JSON Schema, which can be used to generate OpenAPI specs for your Phoenix application.

For example, you can define a `Zoi` schema for a user resource:

```elixir
schema = Zoi.object(%{
  id: Zoi.integer() |> Zoi.min(1),
  name: Zoi.string() |> Zoi.min(1) |> Zoi.max(100),
  age: Zoi.optional(Zoi.integer() |> Zoi.min(0))
})
```

Then, you can convert it to JSON Schema:

```elixir
json_schema = Zoi.to_json_schema(schema)
```

This will generate the following structure:

```elixir
%{
  "$schema" => "https://json-schema.org/draft/2020-12/schema",
  type: :object,
  properties: %{
    id: %{type: :integer, minimum: 1},
    name: %{type: :string, minLength: 1, maxLength: 100},
    age: %{type: :integer, minimum: 0}
  },
  required: [:id, :name],
  additionalProperties: false
}
```

You can then use this JSON Schema to define the request and response bodies in your OpenAPI specification.

## Integrating with Phoenix

To integrate `Zoi` with Phoenix and generate OpenAPI specs, you can create a module that defines your API endpoints and their corresponding `Zoi` schemas. Then, you can use a library like [Oaskit](https://hexdocs.pm/oaskit/index.html) to generate the OpenAPI specification. Follow the Oaskit guide to do the initial setup, then you can use `Zoi` schemas in your endpoint definitions.

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Oaskit.Controller

  alias MyApp.Users

  @user_schema Zoi.object(%{
    id: Zoi.integer() |> Zoi.min(1),
    name: Zoi.string() |> Zoi.min(1) |> Zoi.max(100),
    age: Zoi.optional(Zoi.integer() |> Zoi.min(0))
  })

  @user_spec Zoi.to_json_schema(@user_schema)

  operation :create,
    summary: "Create User",
    request_body: {@user_spec [required: true]},
    responses: [ok: {@user_spec, []}]

    def create(conn, params) do
      ## Validate params using Zoi or Oaskit
    end
end
```

For more details on how to validate parameters in a Phoenix controller using `Zoi`, see the [Validating controller parameters](validating_controller_parameters.md) guide.
