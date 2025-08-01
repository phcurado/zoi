# Zoi

Zoi is a schema validation library for Elixir, inspired by [Zod](https://zod.dev/).

## Installation

`zoi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoi, "~> 0.1.0"}
  ]
end
```

## Usage

You can define schemas and validate data against them. Schemas can be used to validate maps, lists or primitive types such as strings, integers, etc.

```elixir
# Define a schema with primitive type
schema = Zoi.string() |> Zoi.min(3)
Zoi.parse(schema, "hello") # {:ok, "hello"}

# Validate a map with a schema
schema = Zoi.map(%{name: Zoi.string(), age: Zoi.integer()})
Zoi.parse(schema, %{name: "John", age: 30}) # {:ok, %{name: "John", age: 30}}
```

## Roadmap

- [ ] Coerce option for parsing types
- [ ] Allow replacing local declared meta options to parsing options
- [ ] Improve validations, so they don't need to be manually run on every type and manually appended on every validation
- [ ] Implement more types and validations
- [ ] Add guides on how to create custom types and validations
- [ ] Add transform and extend operations for types
- [ ] Interface this library with changesets
