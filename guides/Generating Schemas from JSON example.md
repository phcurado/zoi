# Generating Schemas from JSON example

`Zoi` offers a very flexible way to create schemas and validate data against them. Usually, creating schemas is done programmatically but it can be a tedious task.
In this example, we will demonstrate how to infer schemas from JSON data using `Zoi`.

Let's say that you need to integrate with an external API and they provide you with a sample JSON response:

```json
{
  "data": {
    "id": "60e59b99c8ca1d58514a2322",
    "project_name": "My Project",
    "description": "Project Description",
    "status": "NEW",
    "meta": {
      "id": 10744,
      "name": "Project 1",
      "slug": "/project-1",
      "symbol": "PRD1"
    },
    "start_date": "2021-06-01T22:11:00.000Z",
    "end_date": "2021-07-01T22:11:00.000Z",
    "total_prize": 20000000000,
    "winner_count": 1000,
    "link": "https://example.com"
  },
  "status": {
    "timestamp": "2025-08-29T06:46:37.240Z",
    "error_code": 0,
    "error_message": "message"
  }
}
```

We can use `Zoi` to infer a schema from this JSON data. Here's how you can do it:

```elixir
defmodule ZoiJsonCodegen do
  @moduledoc """
  Generate Elixir source code (as a string) for a Zoi schema from a JSON example.
  """

  def write_module_from_json(json, module_name) do
    body = code_from_json(json)
    mod_file = Path.join("lib", Macro.underscore("#{module_name}") <> ".ex")

    source = """
    defmodule #{module_name} do
      @moduledoc false

      def #{:schema}() do
        #{body}
      end
    end
    """

    formatted = Code.format_string!(source) |> IO.iodata_to_binary()
    File.write!(mod_file, formatted)
    mod_file
  end

  def code_from_json(json) when is_binary(json) do
    json
    |> Jason.decode!()
    |> build_schema_ast()
    |> ast_to_string()
  end

  # Convert quoted AST to pretty Elixir source string
  defp ast_to_string(ast) do
    ast
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.iodata_to_binary()
  end

  # Build AST for a Zoi schema call from decoded JSON
  defp build_schema_ast(v) when is_map(v) do
    map_ast =
      {:%{}, [],
       Enum.map(v, fn {k, vv} ->
         {k, build_schema_ast(vv)}
       end)}

    quote(do: Zoi.object(unquote(map_ast)))
  end

  defp build_schema_ast(v) when is_list(v) do
    inner =
      case v do
        [h | _] -> build_schema_ast(h)
        [] -> quote(do: Zoi.any())
      end

    quote(do: Zoi.array(unquote(inner)))
  end

  defp build_schema_ast(v) when is_binary(v), do: quote(do: Zoi.string())
  defp build_schema_ast(v) when is_integer(v), do: quote(do: Zoi.integer())
  defp build_schema_ast(v) when is_float(v), do: quote(do: Zoi.number())
  defp build_schema_ast(v) when is_boolean(v), do: quote(do: Zoi.boolean())
  defp build_schema_ast(_), do: quote(do: Zoi.optional(Zoi.any()))
end
```

This code might be difficult to understand at first glance, but the key function is `build_schema_ast/1`, which recursively traverses the structure and builds an Elixir AST representing the corresponding `Zoi` schema.

Now we can use this module to generate a schema from the provided JSON example:

```elixir
# Let's use Jason to parse the JSON string into a map
jason_string = "..." # Replace with the JSON string from the example
ZoiJsonCodegen.write_module_from_json(decoded_json, "MyApp.ExternalApiResponse")
```

This will result in a new file `lib/my_app/external_api_response.ex` containing the following schema:

```elixir
defmodule MyApp.ExternalApiResponse do
  @moduledoc false

  def schema() do
    Zoi.object(%{
      "data" =>
        Zoi.object(%{
          "description" => Zoi.string(),
          "end_date" => Zoi.string(),
          "id" => Zoi.string(),
          "link" => Zoi.string(),
          "meta" =>
            Zoi.object(%{
              "id" => Zoi.integer(),
              "name" => Zoi.string(),
              "slug" => Zoi.string(),
              "symbol" => Zoi.string()
            }),
          "project_name" => Zoi.string(),
          "start_date" => Zoi.string(),
          "status" => Zoi.string(),
          "total_prize" => Zoi.integer(),
          "winner_count" => Zoi.integer()
        }),
      "status" =>
        Zoi.object(%{
          "error_code" => Zoi.integer(),
          "error_message" => Zoi.string(),
          "timestamp" => Zoi.string()
        })
    })
  end
end
```

This is a fully functional `Zoi` schema that you can use to validate data received from the external API. The generator is quite basic and may not cover all edge cases, but it provides a solid starting point for generating schemas from JSON examples.
