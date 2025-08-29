# Converting Keys From Object

In `Zoi` you can also apply complex transformations to keys in maps. This is useful when you want to convert keys from one format to another, such as from camelCase to snake_case.

For example, consider the following JSON data:

```json
{
  "firstName": "John",
  "lastName": "Doe",
  "address": {
    "streetAddress": "21 2nd Street",
    "city": "New York"
  }
}
```

If you want to transform the keys to snake_case, you can use `Zoi.transform/2` as follows:

```elixir
defmodule MyApp.User do
  @moduledoc false

  def schema() do
    Zoi.object(%{
      "firstName" => Zoi.string(),
      "lastName" => Zoi.string(),
      "address" =>
        Zoi.object(%{
          "streetAddress" => Zoi.string(),
          "city" => Zoi.string()
        })
        |> to_snake_case()
    })
    |> to_snake_case()
  end

  defp to_snake_case(schema) do
    schema
    |> Zoi.transform(fn map ->
      for {k, v} <- map, into: %{}, do: {Macro.underscore(k), v}
    end)
  end
end
```

Now, when you validate data against this schema, the keys will be transformed to snake_case:

```elixir
iex> schema = MyApp.User.schema()
iex> Zoi.parse(schema, %{"firstName" => "John", "lastName" => "Doe", "address" => %{"streetAddress" => "21 2nd Street", "city" => "New York"}})
{:ok, %{"first_name" => "John", "last_name" => "Doe", "address" => %{"street_address" => "21 2nd Street", "city" => "New York"}}}
```

You can also apply key transformation, for example if the data to be validated doesn't really have consistent keys, or if you want to normalize keys before validation.

```elixir
defmodule MyApp.User do
  @moduledoc false

  def schema() do
    Zoi.object(%{
      "@name" => Zoi.string(),
      "__last_name__" => Zoi.string()
    })
    |> map_to_atom_keys()
  end

  defp map_to_atom_keys(schema) do
    schema
    |> Zoi.transform(fn map ->
      Enum.map(map, fn {k, v} ->
        case k do
          "@name" -> {:name, v}
          "__last_name__" -> {:last_name, v}
          other -> {other, v}
        end
      end)
      |> Enum.into(%{})
    end)
  end
end
```

Now when you validate data against this schema, the keys will be transformed to the desired format:

```elixir
iex> schema = MyApp.User.schema()
iex> Zoi.parse(schema, %{"@name" => "John", "__last_name__" => "Doe"})
{:ok, %{name: "John", last_name: "Doe"}}
```

And the error messages will reflect the parameter keys before transformation:

```elixir
iex> Zoi.parse(schema, %{"@name" => "John"})
{:error, [%Zoi.Error{message: "is required", path: ["__last_name__"]}]}
```
