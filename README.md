# Zoi

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `zoi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoi, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/zoi>.

## Roadmap

- [ ] Coerce option for parsing types
- [ ] Allow replacing local declared meta options to parsing options
- [ ] Improve validations, so they don't need to be manually run on every type and manually appended on every validation
- [ ] Implement more types and validations
- [ ] Add guides on how to create custom types and validations
- [ ] Add transform and extend operations for types
- [ ] Interface this library with changesets
