defmodule Zoi do
  @moduledoc """
  `Zoi` is a schema validation library for Elixir, designed to provide a simple and flexible way to define and validate data.

  It allows you to create schemas for various data types, including strings, integers, booleans, and complex objects, with built-in support for validations like minimum and maximum values, regex patterns, and email formats.

      user = Zoi.object(%{
        name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
        age: Zoi.integer() |> Zoi.min(18) |> Zoi.max(120),
        email: Zoi.email()
      })

      Zoi.parse(user, %{
        name: "Alice",
        age: 30,
        email: "alice@email.com"
      })
      # {:ok, %{name: "Alice", age: 30, email: "alice@email.com"}}

  ## Coercion

  By default, `Zoi` will not attempt to infer input data to match the expected type. For example, if you define a schema that expects a string, passing an integer will result in an error.
      iex> Zoi.string() |> Zoi.parse(123)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected string",
           issue: {"invalid type: expected string", [type: :string]},
           path: []
         }
       ]}

  If you need coercion, you can enable it by passing the `:coerce` option:

      iex> Zoi.string(coerce: true) |> Zoi.parse(123)
      {:ok, "123"}

  ## Refinements

  Refinements are custom validation functions that you can attach to any schema. They allow you to define complex validation logic that goes beyond the built-in validations provided by `Zoi`.

      iex> schema = Zoi.integer() |> Zoi.refine(fn value ->
      ...>   if value > 0 do
      ...>     :ok
      ...>   else
      ...>     {:error, "must be a positive number"}
      ...>   end
      ...> end)
      iex> Zoi.parse(schema, 4)
      {:ok, 4}
      iex> Zoi.parse(schema, -1)
      {:error,
        [
          %Zoi.Error{
            code: :custom,
            message: "must be a positive number",
            issue: {"must be a positive number", []},
            path: []
          }
        ]}

  `Zoi` also have built-in refinements for common validations, check the `Refinements` section for more details. The example above can be rewritten using the built-in `Zoi.positive/2` refinement:

      iex> schema = Zoi.integer() |> Zoi.positive()
      iex> Zoi.parse(schema, 4)
      {:ok, 4}
      iex> Zoi.parse(schema, -1)
      {:error,
        [
          %Zoi.Error{
            code: :greater_than,
            message: "too small: must be greater than 0",
            issue: {"too small: must be greater than %{count}", [count: 0]},
            path: []
          }
        ]}


  ## Transforms

  Transforms are functions that modify the input data before it is returned as the final parsed value. They can be used to format, normalize, or otherwise change the data as needed.

      iex> schema = Zoi.string() |> Zoi.transform(fn value ->
      ...>   String.upcase(value)
      ...> end)
      iex> Zoi.parse(schema, "hello")
      {:ok, "HELLO"}

  `Zoi` also provides built-in transformations. Check the `Transforms` section for more details. The example above can be rewritten using the built-in `Zoi.to_upcase/1` transform:

      iex> schema = Zoi.string() |> Zoi.to_upcase()
      iex> Zoi.parse(schema, "hello")
      {:ok, "HELLO"}

  ## Custom errors

  You can customize error messages for all types by passing the `error` option:

      iex> schema = Zoi.integer(error: "must be a number")
      iex> Zoi.parse(schema, "a")
      {:error,
       [
         %Zoi.Error{
           code: :custom,
           message: "must be a number",
           issue: {"must be a number", [type: :integer]},
           path: []
         }
       ]}

  This also works for refinements:
      iex> schema = Zoi.number() |> Zoi.gte(10, error: "please provide a number bigger than %{count}")
      iex> Zoi.parse(schema, 5)
      {:error,
       [
         %Zoi.Error{
           code: :custom,
           message: "please provide a number bigger than 10",
           issue: {"please provide a number bigger than %{count}", [count: 10]},
           path: []
          }
       ]}

  `Zoi` automatically interpolates values in the error messages using the `issue` tuple. In the above example, `%{count}` is replaced with `10`.
  For more information on what values are available for interpolation, check the documentation of each validation function.

  ## Architecture Summary

  Basically `Zoi` is built around a core parsing, running validations and transformations in order to achieve the final parsed output. The parsing sequence is summarized by the diagram below:

  ```mermaid
  flowchart LR
  ui(Unknown Input) --> parse(Parse Type) --> effects(Effects: transforms & refines in chain order) --> output(Parsed Output)
  ```

  Effects (transforms and refines) execute in the order they are chained, allowing flexible composition:

      Zoi.string()
      |> Zoi.min(3)                      # refine
      |> Zoi.transform(&String.trim/1)   # transform
      |> Zoi.refine(fn s -> ... end)     # refine
      |> Zoi.transform(&String.upcase/1) # transform
  """

  alias Zoi.Regexes

  @typedoc "The schema definition."
  @type schema :: Zoi.Type.t()

  @typedoc "The input data to be validated against a schema."
  @type input :: any()

  @typedoc "The result of parsing, either `{:ok, value}` or `{:error, errors}`."
  @type result :: {:ok, any()} | {:error, [Zoi.Error.t() | binary()]}

  @typedoc "Options for parsing and schema definitions."
  @type options :: keyword()

  @typedoc "Refinement function or module specification."
  @type refinement ::
          {module(), atom(), [any()]}
          | (input() -> :ok | {:error, binary()})
          | (input(), Zoi.Context.t() -> :ok | {:error, binary()})

  @typedoc "Transformation function or module specification."
  @type transform ::
          {module(), atom(), [any()]}
          | (input() -> {:ok, input()} | {:error, binary()} | input())
          | (input(), Zoi.Context.t() ->
               {:ok, input()} | {:error, binary()} | input())

  @doc """
  Parse input data against a schema.
  Accepts optional `coerce: true` option to enable coercion.
  ## Examples

      iex> schema = Zoi.string() |> Zoi.min(2) |> Zoi.max(100)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "h")
      {:error,
       [
         %Zoi.Error{
           code: :greater_than_or_equal_to,
           message: "too small: must have at least 2 character(s)",
           issue: {"too small: must have at least %{count} character(s)", [count: 2]},
           path: []
         }
       ]}
      iex> Zoi.parse(schema, 123, coerce: true)
      {:ok, "123"}
  """
  @doc group: "Parsing"
  @spec parse(schema :: schema(), input :: input(), opts :: options()) :: result()
  def parse(schema, input, opts \\ []) do
    ctx = Zoi.Context.new(schema, input)
    opts = Keyword.put_new(opts, :ctx, ctx)

    case Zoi.Context.parse(ctx, opts) do
      %Zoi.Context{valid?: true, parsed: parsed} ->
        {:ok, parsed}

      %Zoi.Context{valid?: false, errors: errors} ->
        {:error, errors}
    end
  end

  @doc """
  Similar to `Zoi.parse/3`, but raises an error if parsing fails.

  ## Examples
      schema = Zoi.string() |> Zoi.min(2) |> Zoi.max(100)
      Zoi.parse!(schema, "hello")
      #=> "hello"
      Zoi.parse!(schema, "h")
      # ** (Zoi.ParseError) Parsing error:
      #
      # too small: must have at least 2 characters
  """
  @doc group: "Parsing"
  @spec parse!(schema :: schema(), input :: input(), opts :: options()) :: any()
  def parse!(schema, input, opts \\ []) do
    case parse(schema, input, opts) do
      {:ok, result} ->
        result

      {:error, errors} ->
        raise Zoi.ParseError, errors: errors
    end
  end

  @doc """
  Generates the Elixir type specification for a given schema.

  ## Example

      defmodule MyApp.Schema do
        @schema Zoi.string() |> Zoi.min(2) |> Zoi.max(100)
        @type t :: unquote(Zoi.type_spec(@schema))
      end

  This will generate the following type specification:
      @type t :: binary()

  This also applies to complex types, such as `Zoi.object/2`:

      defmodule MyApp.User do
        @schema Zoi.object(%{
          name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
          age: Zoi.integer() |> Zoi.optional(),
          email: Zoi.email()
        })
        @type t :: unquote(Zoi.type_spec(@schema))
      end

  Which will generate:
      @type t :: %{
        required(:name) => binary(),
        optional(:age) => integer(),
        required(:email) => binary()
      }

  Union types are also supported:

        Zoi.union([Zoi.string(), Zoi.integer()])
        #=> binary() | integer()

  All the types provided by `Zoi` supports the type spec generation.
  """
  @doc group: "Parsing"
  @spec type_spec(schema :: schema(), opts :: options()) :: Macro.t()
  def type_spec(schema, opts \\ []) do
    Zoi.Type.type_spec(schema, opts)
  end

  @doc """
  Retrieves the description associated with the schema.
  It's often useful to store additional information about the schema, describing its purpose or usage.
  Currently the `:description` is used generating a description for json schema.
  Check the `Zoi.JSONSchema` module for more details.

  ## Example

      iex> schema = Zoi.string(description: "Defines the name of the user")
      iex> Zoi.description(schema)
      "Defines the name of the user"
  """
  @doc group: "Parsing"
  @spec description(schema :: schema()) :: binary() | nil
  def description(schema) do
    schema.meta.description
  end

  @doc """
  Retrieves an example value from the schema. If no example is defined, it returns `nil`.

  ## Example

      iex> schema = Zoi.string(example: "example string")
      iex> Zoi.example(schema)
      "example string"

  This directive is specally useful for documentation and testing purposes.
  As an example, you can define a schema as it follows:

      defmodule MyApp.UserSchema do
        @schema Zoi.object(
                  %{
                    name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
                    age: Zoi.integer() |> Zoi.optional()
                  },
                  example: %{name: "Alice", age: 30}
                )

        def schema, do: @schema
      end

  Then you can test if the example matches the schema:

      defmodule MyApp.UserSchemaTest do
        use ExUnit.Case
        alias MyApp.UserSchema

        test "example matches schema" do
          example = Zoi.example(UserSchema.schema())
          assert {:ok, example} == Zoi.parse(UserSchema.schema(), example)
        end
      end
  """
  @doc group: "Parsing"
  @spec example(schema :: schema()) :: input()
  def example(schema) do
    schema.meta.example
  end

  @doc ~S"""
  Retrieves the metadata associated with the schema.
  It's often useful to store additional information about the schema, such as descriptions, titles, or custom identifiers.

  ## Example

      iex> schema = Zoi.string(metadata: [identifier: "string/1", for: "username"])
      iex> Zoi.metadata(schema)
      [identifier: "string/1", for: "username"]

  You can also add an example helper that can be used on own elixir docs:

      defmodule MyApp.UserSchema do
        @schema Zoi.object(
                  %{
                    name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
                    age: Zoi.integer() |> Zoi.optional()
                  },
                  metadata: [
                    doc: "A user schema with name and optional age",
                    moduledoc: "Schema representing a user with name and optional age"
                  ]
                )
        @moduledoc \"""
        #{Zoi.metadata(@schema)[:moduledoc]}
        \"""

        @doc \"""
        #{Zoi.metadata(@schema)[:doc]}
        \"""
        def schema, do: @schema
      end

  The metadata is flexible, allowing you to store any key-value pairs that suit your needs.
  """
  @doc group: "Parsing"
  @spec metadata(schema :: schema()) :: keyword()
  def metadata(schema) do
    schema.meta.metadata
  end

  @doc """
  Enables coercion on a schema.

  This is a helper function that enables type coercion on schemas that support it.
  Types that don't have a `:coerce` field are returned unchanged.

  Coercion allows automatic type conversion of input data. For example, the string `"42"`
  can be coerced to the integer `42`, or the string `"true"` to the boolean `true`.

  ## Example

      iex> schema = Zoi.integer() |> Zoi.coerce()
      iex> Zoi.parse(schema, "42")
      {:ok, 42}

  For nested schemas, use `Zoi.Schema.traverse/2` to enable coercion on child fields.
  Note that traverse only applies to nested fields, not the root schema:

      iex> schema = Zoi.object(%{age: Zoi.integer()}) |> Zoi.Schema.traverse(&Zoi.coerce/1) |> Zoi.coerce()
      iex> Zoi.parse(schema, %{"age" => "25"})
      {:ok, %{age: 25}}
  """
  @doc group: "Parsing"
  @doc since: "0.11.0"
  @spec coerce(schema :: schema()) :: schema()
  def coerce(%{coerce: _} = schema), do: %{schema | coerce: true}
  def coerce(schema), do: schema

  @doc """
  Converts a list of errors into a tree structure, where each error is placed at its corresponding path.

  This is useful for displaying validation errors in a structured way, such as in a form.

  ## Example

      iex> errors = [
      ...>   %Zoi.Error{path: ["name"], message: "is required"},
      ...>   %Zoi.Error{path: ["age"], message: "invalid type: must be an integer"},
      ...>   %Zoi.Error{path: ["address", "city"], message: "is required"}
      ...> ]
      iex> Zoi.treefy_errors(errors)
      %{
        "name" => ["is required"],
        "age" => ["invalid type: must be an integer"],
        "address" => %{
          "city" => ["is required"]
        }
      }

  If you use this function on types without path (like `Zoi.string()`), it will create a top-level `:__errors__` key:

      iex> errors = [%Zoi.Error{message: "invalid type: must be a string"}]
      iex> Zoi.treefy_errors(errors)
      %{__errors__: ["invalid type: must be a string"]}

  Errors without a path are considered top-level errors and are grouped under `:__errors__`.
  This is how `Zoi` also handles errors when `Zoi.object/2` is used with `:strict` option, where unrecognized keys are added to the `:__errors__` key.
  """
  @doc group: "Parsing"
  @spec treefy_errors([Zoi.Error.t()]) :: map()
  def treefy_errors(errors) when is_list(errors) do
    Enum.reduce(errors, %{}, fn %Zoi.Error{path: path} = error, acc ->
      insert_error(acc, path, error.message)
    end)
  end

  defp insert_error(acc, [], error) do
    Map.update(acc, :__errors__, [error], fn existing -> existing ++ [error] end)
  end

  defp insert_error(acc, [key], error) do
    Map.update(acc, key, [error], fn existing -> existing ++ [error] end)
  end

  defp insert_error(acc, [key | rest], error) do
    nested = Map.get(acc, key, %{})
    Map.put(acc, key, insert_error(nested, rest, error))
  end

  @doc """
  Converts a list of errors into a human-readable string format.
  Each error is displayed on a new line, with its message and path.
  ## Example

      iex> errors = [
      ...>   %Zoi.Error{path: ["name"], message: "is required"},
      ...>   %Zoi.Error{path: ["age"], message: "invalid type: must be an integer"},
      ...>   %Zoi.Error{path: ["address", "city"], message: "is required"}
      ...> ]
      iex> Zoi.prettify_errors(errors)
      "is required, at name\\ninvalid type: must be an integer, at age\\nis required, at address.city"

      iex> errors = [%Zoi.Error{message: "invalid type: must be a string"}]
      iex> Zoi.prettify_errors(errors)
      "invalid type: must be a string"
  """
  @doc group: "Parsing"
  @spec prettify_errors([Zoi.Error.t() | binary()]) :: binary()
  def prettify_errors(errors) when is_list(errors) do
    Enum.reduce(errors, "", fn error, acc ->
      if acc == "" do
        prettify_error(error)
      else
        acc <> "\n" <> prettify_error(error)
      end
    end)
  end

  defp prettify_error(%Zoi.Error{message: message, path: []}) do
    message
  end

  defp prettify_error(%Zoi.Error{message: message, path: path}) do
    path_str =
      Enum.with_index(path)
      |> Enum.reduce("", fn {segment, index}, acc ->
        cond do
          is_integer(segment) ->
            acc <> "[#{segment}]"

          index == 0 ->
            acc <> "#{segment}"

          true ->
            acc <> ".#{segment}"
        end
      end)

    "#{message}, at #{path_str}"
  end

  @doc """
  See `Zoi.JSONSchema`
  """
  @doc group: "Parsing"
  @spec to_json_schema(schema :: schema()) :: map()
  defdelegate to_json_schema(schema), to: Zoi.JSONSchema, as: :encode

  @doc """
  See `Zoi.Describe`
  """
  @doc group: "Parsing"
  @spec describe(schema :: schema()) :: binary()
  defdelegate describe(schema), to: Zoi.Describe, as: :generate

  # Types

  @doc """
  Defines a string type schema.

  ## Example

      iex> schema = Zoi.string()
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, :world)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected string",
           issue: {"invalid type: expected string", [type: :string]},
           path: []
         }
       ]}

  Zoi provides built-in validations for strings, such as:

      Zoi.min(2)
      Zoi.max(100)
      Zoi.length(5)
      Zoi.starts_with("hello")
      Zoi.ends_with("world")
      Zoi.regex(~r/^[a-zA-Z]+$/)

  Additionally it can perform data transformation:
      Zoi.string()
      |> Zoi.trim()
      |> Zoi.to_downcase()
      |> Zoi.to_uppercase()

  for coercion, you can pass the `:coerce` option:
      iex> Zoi.string(coerce: true) |> Zoi.parse(123)
      {:ok, "123"}
  """
  @doc group: "Basic Types"
  @spec string(opts :: options()) :: schema()
  defdelegate string(opts \\ []), to: Zoi.Types.String, as: :new

  @doc """
  Defines a number type schema.

  ## Example

      iex> shema = Zoi.integer()
      iex> Zoi.parse(shema, 42)
      {:ok, 42}
      iex> Zoi.parse(shema, "42")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected integer",
           issue: {"invalid type: expected integer", [type: :integer]},
           path: []
         }
       ]}

  For coercion, you can pass the `:coerce` option:
      iex> Zoi.integer(coerce: true) |> Zoi.parse("42")
      {:ok, 42}
  """
  @doc group: "Basic Types"
  @spec integer(opts :: options()) :: schema()
  defdelegate integer(opts \\ []), to: Zoi.Types.Integer, as: :new

  @doc """
  Defines a float type schema.

  ## Example

      iex> schema = Zoi.float()
      iex> Zoi.parse(schema, 3.14)
      {:ok, 3.14}

  Built-in validations for floats include:
      Zoi.min(0.0)
      Zoi.max(100.0)

  For coercion, you can pass the `:coerce` option:
      iex> Zoi.float(coerce: true) |> Zoi.parse("3.14")
      {:ok, 3.14}
  """
  @doc group: "Basic Types"
  @spec float(opts :: options()) :: schema()
  defdelegate float(opts \\ []), to: Zoi.Types.Float, as: :new

  @doc """
  Defines the numeric type schema.

  This type is a union of `Zoi.integer()` and `Zoi.float()`, allowing you to validate both integers and floats.
  ## Example

      iex> schema = Zoi.number()
      iex> Zoi.parse(schema, 42)
      {:ok, 42}
      iex> Zoi.parse(schema, 3.14)
      {:ok, 3.14}
      iex> Zoi.parse(schema, "42")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected number",
           issue: {"invalid type: expected number", [type: :number]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  @spec number(opts :: options()) :: schema()
  defdelegate number(opts \\ []), to: Zoi.Types.Number, as: :new

  @doc """
  Defines a boolean type schema.

  ## Example

      iex> schema = Zoi.boolean()
      iex> Zoi.parse(schema, true)
      {:ok, true}

  For coercion, you can pass the `:coerce` option:
      iex> Zoi.boolean(coerce: true) |> Zoi.parse("true")
      {:ok, true}
  """
  @doc group: "Basic Types"
  @spec boolean(opts :: options()) :: schema()
  defdelegate boolean(opts \\ []), to: Zoi.Types.Boolean, as: :new

  @doc """
  Defines a string boolean type schema.

  This type parses "boolish" string values:
      # thruthy values: true, "true", "1", "yes", "on", "y", "enabled"
      # falsy values: false, "false", "0", "no", "off", "n", "disabled"


  ## Example

      iex> schema = Zoi.string_boolean()
      iex> Zoi.parse(schema, "true")
      {:ok, true}
      iex> Zoi.parse(schema, "false")
      {:ok, false}
      iex> Zoi.parse(schema, "yes")
      {:ok, true}
      iex> Zoi.parse(schema, "no")
      {:ok, false}

  You can also specify custom truthy and falsy values using the `:truthy` and `:falsy` options:
      iex> schema = Zoi.string_boolean(truthy: ["yes", "y"], falsy: ["no", "n"])
      iex> Zoi.parse(schema, "yes")
      {:ok, true}
      iex> Zoi.parse(schema, "no")
      {:ok, false}

  By default the string boolean type is case insensitive and the input is converted to lowercase during the comparison. You can change this behavior using the `:case` option:

      iex> schema = Zoi.string_boolean(case: "sensitive")
      iex> Zoi.parse(schema, "True")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected string boolean",
           issue: {"invalid type: expected string boolean", [type: :string_boolean]},
           path: []
         }
       ]}
      iex> Zoi.parse(schema, "true")
      {:ok, true}
  """
  @doc group: "Basic Types"
  @spec string_boolean(opts :: options()) :: schema()
  defdelegate string_boolean(opts \\ []), to: Zoi.Types.StringBoolean, as: :new

  @doc """
  Defines a schema that accepts any type of input.

  This is useful when you want to allow any data type without validation.

  ## Example

      iex> schema = Zoi.any()
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, 42)
      {:ok, 42}
      iex> Zoi.parse(schema, %{key: "value"})
      {:ok, %{key: "value"}}
  """
  @doc group: "Basic Types"
  @spec any(opts :: options()) :: schema()
  defdelegate any(opts \\ []), to: Zoi.Types.Any, as: :new

  @doc """
  Defines an atom type schema.

  ## Examples
      iex> schema = Zoi.atom()
      iex> Zoi.parse(schema, :atom)
      {:ok, :atom}
      iex> Zoi.parse(schema, "not_an_atom")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected atom",
           issue: {"invalid type: expected atom", [type: :atom]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  @spec atom(opts :: options()) :: schema()
  defdelegate atom(opts \\ []), to: Zoi.Types.Atom, as: :new

  @doc """
  Defines a literal type schema.
  This schema only accepts a specific literal value as valid input.

  ## Example
      iex> schema = Zoi.literal(true)
      iex> Zoi.parse(schema, true)
      {:ok, true}
      iex> Zoi.parse(schema, :other_value)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_literal,
           message: "invalid literal: expected true",
           issue: {"invalid literal: expected %{expected}", [expected: true]},
           path: []
         }
       ]}
      iex> schema = Zoi.literal(42)
      iex> Zoi.parse(schema, 42)
      {:ok, 42}
      iex> Zoi.parse(schema, 43)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_literal,
           message: "invalid literal: expected 42",
           issue: {"invalid literal: expected %{expected}", [expected: 42]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  @spec literal(value :: input(), opts :: options()) :: schema()
  defdelegate literal(value, opts \\ []), to: Zoi.Types.Literal, as: :new

  @doc """
  Defines a nil type schema.
  This schema only accepts `nil` as valid input.
  ## Example

      iex> schema = Zoi.null()
      iex> Zoi.parse(schema, nil)
      {:ok, nil}
      iex> Zoi.parse(schema, "not_nil")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected nil",
           issue: {"invalid type: expected nil", [type: nil]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  @spec null(opts :: options()) :: schema()
  defdelegate null(opts \\ []), to: Zoi.Types.Null, as: :new

  @doc """
  Makes the schema optional for the `Zoi.object/2` and `Zoi.keyword/2` types.

  ## Example

      iex> schema = Zoi.object(%{name: Zoi.string() |> Zoi.optional()})
      iex> Zoi.parse(schema, %{})
      {:ok, %{}}
  """
  @doc group: "Encapsulated Types"
  @spec optional(inner :: schema()) :: schema()
  defdelegate optional(inner), to: Zoi.Types.Optional, as: :new

  @doc """
  Makes the schema required for the `Zoi.object/2` and `Zoi.keyword/2` types.

  ## Example

      iex> schema = Zoi.keyword([name: Zoi.string() |> Zoi.required()])
      iex> Zoi.parse(schema, [])
      {:error,
       [
         %Zoi.Error{
           code: :required,
           message: "is required",
           issue: {"is required", [key: :name]},
           path: [:name]
         }
       ]}
  """
  @doc group: "Encapsulated Types"
  @spec required(inner :: schema()) :: schema()
  defdelegate required(inner), to: Zoi.Types.Required, as: :new

  @doc """
  Defines a schema that allows `nil` values.

  ## Examples
      iex> schema = Zoi.string() |> Zoi.nullable()
      iex> Zoi.parse(schema, nil)
      {:ok, nil}
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
  """
  @doc group: "Encapsulated Types"
  @spec nullable(inner :: schema(), opts :: options()) :: schema()
  defdelegate nullable(inner, opts \\ []), to: Zoi.Types.Nullable, as: :new

  @doc """
  Makes the schema optional and nullable for the `Zoi.object/2` and `Zoi.keyword/2` types.

  ## Example
      iex> schema = Zoi.object(%{name: Zoi.string() |> Zoi.nullish()})
      iex> Zoi.parse(schema, %{})
      {:ok, %{}}
      iex> Zoi.parse(schema, %{name: nil})
      {:ok, %{name: nil}}
  """
  @doc group: "Encapsulated Types"
  @doc since: "0.7.5"
  @spec nullish(inner :: schema(), opts :: options()) :: schema()
  defdelegate nullish(inner, opts \\ []), to: Zoi.Types.Nullish, as: :new

  @doc """
  Creates a default value for the schema.

  This allows you to specify a default value that will be used if the input is `nil` or not provided.

  ## Example
      iex> schema = Zoi.string() |> Zoi.default("default value")
      iex> Zoi.parse(schema, nil)
      {:ok, "default value"}

  """
  @doc group: "Encapsulated Types"
  @spec default(inner :: schema(), value :: input(), opts :: options()) :: schema()
  defdelegate default(inner, value, opts \\ []), to: Zoi.Types.Default, as: :new

  @doc """
  Defines a union type schema.

  ## Example

      iex> schema = Zoi.union([Zoi.string(), Zoi.integer()])
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, 42)
      {:ok, 42}
      iex> Zoi.parse(schema, true)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected integer",
           issue: {"invalid type: expected integer", [type: :integer]},
           path: []
         }
       ]}

  This type also allows to define validations for each type in the union:

      iex> schema = Zoi.union([
      ...>   Zoi.string() |> Zoi.min(2),
      ...>   Zoi.integer() |> Zoi.min(0)
      ...> ])
      iex> Zoi.parse(schema, "h") # fails on string and try to parse as integer
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected integer",
           issue: {"invalid type: expected integer", [type: :integer]},
           path: []
         }
       ]}
      iex> Zoi.parse(schema, -1)
      {:error,
       [
         %Zoi.Error{
           code: :greater_than_or_equal_to,
           message: "too small: must be at least 0",
           issue: {"too small: must be at least %{count}", [count: 0]},
           path: []
         }
       ]}

  If you define the validation on the union itself, it will apply to all types in the union:

      iex> schema = Zoi.union([
      ...>   Zoi.string(),
      ...>   Zoi.integer()
      ...> ]) |> Zoi.min(3)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, 2)
      {:error,
       [
         %Zoi.Error{
           code: :greater_than_or_equal_to,
           message: "too small: must be at least 3",
           issue: {"too small: must be at least %{count}", [count: 3]},
           path: []
         }
       ]}
  """
  @doc group: "Encapsulated Types"
  @spec union(fields :: [schema()], opts :: options()) :: schema()
  defdelegate union(fields, opts \\ []), to: Zoi.Types.Union, as: :new

  @doc """
  Defines an intersection type schema.

  An intersection type allows you to combine multiple schemas into one, requiring that the input data satisfies all of them.

  ## Example

      iex> schema = Zoi.intersection([
      ...>   Zoi.string() |> Zoi.min(2),
      ...>   Zoi.string() |> Zoi.max(5)
      ...> ])
      iex> Zoi.parse(schema, "helloworld")
      {:error,
       [
         %Zoi.Error{
           code: :less_than_or_equal_to,
           message: "too big: must have at most 5 character(s)",
           issue: {"too big: must have at most %{count} character(s)", [count: 5]},
           path: []
         }
       ]}
      iex> Zoi.parse(schema, "hi")
      {:ok, "hi"}

  If you define the validation on the intersection itself, it will apply to all types in the intersection:

      iex> schema = Zoi.intersection([
      ...>   Zoi.string(),
      ...>   Zoi.integer(coerce: true)
      ...> ]) |> Zoi.min(3)
      iex> Zoi.parse(schema, "115")
      {:ok, 115}
      iex> Zoi.parse(schema, "2")
      {:error,
       [
         %Zoi.Error{
           code: :greater_than_or_equal_to,
           message: "too small: must have at least 3 character(s)",
           issue: {"too small: must have at least %{count} character(s)", [count: 3]},
           path: []
         }
       ]}
  """
  @doc group: "Encapsulated Types"
  @spec intersection(fields :: [schema()], opts :: options()) :: schema()
  defdelegate intersection(fields, opts \\ []), to: Zoi.Types.Intersection, as: :new

  @doc """
  Defines a object type schema.

  Use `Zoi.object(fields)` to define complex objects with nested schemas:

      iex> user_schema = Zoi.object(%{
      ...> name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
      ...> age: Zoi.integer() |> Zoi.min(18) |> Zoi.max(120),
      ...> email: Zoi.email()
      ...> })
      iex> Zoi.parse(user_schema, %{name: "Alice", age: 30, email: "alice@email.com"})
      {:ok, %{name: "Alice", age: 30, email: "alice@email.com"}}

  By default all fields are required, but you can make them optional by using `Zoi.optional/1`:

      iex> user_schema = Zoi.object(%{
      ...> name: Zoi.string() |> Zoi.optional(),
      ...> age: Zoi.integer() |> Zoi.optional(),
      ...> email: Zoi.email() |> Zoi.optional()
      ...> })
      iex> Zoi.parse(user_schema, %{name: "Alice"})
      {:ok, %{name: "Alice"}}

  By default, unrecognized keys will be removed from the parsed data. If you want to not allow unrecognized keys, use the `:strict` option:

      iex> schema = Zoi.object(%{name: Zoi.string()}, strict: true)
      iex> Zoi.parse(schema, %{name: "Alice", age: 30})
      {:error,
       [
         %Zoi.Error{
           code: :unrecognized_key,
           message: "unrecognized key: 'age'",
           issue: {"unrecognized key: '%{key}'", [key: :age]},
           path: []
         }
       ]}

  ## String keys and Atom keys

  Objects can be declared using string keys too, this would set the expectation that the param data is also using string keys:

      iex> schema = Zoi.object(%{"name" => Zoi.string()})
      iex> Zoi.parse(schema, %{"name" => "Alice"})
      {:ok, %{"name" => "Alice"}}
      iex> Zoi.parse(schema, %{name: "Alice"})
      {:error,
       [
         %Zoi.Error{
           code: :required,
           message: "is required",
           issue: {"is required", [key: "name"]},
           path: ["name"]
         }
       ]}

  It's possible coerce the keys to atoms using the `:coerce` option:

      iex> schema = Zoi.object(%{name: Zoi.string()}, coerce: true)
      iex> Zoi.parse(schema, %{"name" => "Alice"})
      {:ok, %{name: "Alice"}}

  Which will automatically convert string keys to atom keys.


  ## Nullable vs Optional fields

  The `Zoi.optional/1` function makes a field optional, meaning it can be omitted from the input data. If the field is not present, it will not be included in the parsed result.
  The `Zoi.nullable/1` function allows a field to be `nil`, meaning it can be explicitly set to `nil` in the input data. If the field is set to `nil`, it will be included in the parsed result as `nil`.

      iex> schema = Zoi.object(%{name: Zoi.string() |> Zoi.optional(), age: Zoi.integer() |> Zoi.nullable()})
      iex> Zoi.parse(schema, %{name: "Alice", age: nil})
      {:ok, %{name: "Alice", age: nil}}
      iex> Zoi.parse(schema, %{name: "Alice"})
      {:error,
       [
         %Zoi.Error{
           code: :required,
           message: "is required",
           issue: {"is required", [key: :age]},
           path: [:age]
         }
       ]}

  ## Optional vs Default fields

  There are two options to define the behaviour of a field being optional and with a default value:
  1. If the field is not present in the input data OR `nil`, it will be included in the parsed result with the default value.
  2. If the field not present in the input data, it will not be included on the parsed result. If the value is `nil`, it will be included in the parsed result with the default value.

  The order you encapsulate the type matters, to implement the first option, the encapsulation should be `Zoi.default(Zoi.optional(type, default_value))`:

      iex> schema = Zoi.object(%{name: Zoi.default(Zoi.optional(Zoi.string()), "default value")})
      iex> Zoi.parse(schema, %{})
      {:ok, %{name: "default value"}}
      iex> Zoi.parse(schema, %{name: nil})
      {:ok, %{name: "default value"}}

  The second option is implemented by encapsulating the type as `Zoi.optional(Zoi.default(type, default_value))`:

      iex> schema = Zoi.object(%{name: Zoi.optional(Zoi.default(Zoi.string(), "default value"))})
      iex> Zoi.parse(schema, %{})
      {:ok, %{}}
      iex> Zoi.parse(schema, %{name: nil})
      {:ok, %{name: "default value"}}

  ## Required definition

  By default, all fields are required and if the field is absent in the input data, a validation error will be raised.
  You can customize absent values in your object definition, defining what values should be considered absent using the `:empty_values` option:

      iex> schema = Zoi.object(%{name: Zoi.string()}, empty_values: [nil, ""])
      iex> Zoi.parse(schema, %{name: ""})
      {:error,
       [
         %Zoi.Error{
           code: :required,
           message: "is required",
           issue: {"is required", [key: :name]},
           path: [:name]
         }
       ]}
  """
  @doc group: "Complex Types"
  @spec object(fields :: map(), opts :: options()) :: schema()
  defdelegate object(fields, opts \\ []), to: Zoi.Types.Object, as: :new

  @doc """
  Defines a keyword list type schema.

      iex> schema = Zoi.keyword(name: Zoi.string(), age: Zoi.integer())
      iex> Zoi.parse(schema, [name: "Alice", age: 30])
      {:ok, [name: "Alice", age: 30]}
      iex> Zoi.parse(schema, %{name: "Alice", age: 30})
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected keyword list",
           issue: {"invalid type: expected keyword list", [type: :keyword]},
           path: []
         }
       ]}

  By default, unrecognized keys will be removed from the parsed data. If you want to not allow unrecognized keys, use the `:strict` option:

      iex> schema = Zoi.keyword([name: Zoi.string()], strict: true)
      iex> Zoi.parse(schema, [name: "Alice", age: 30])
      {:error,
       [
         %Zoi.Error{
           code: :unrecognized_key,
           message: "unrecognized key: 'age'",
           issue: {"unrecognized key: '%{key}'", [key: :age]},
           path: []
         }
       ]}

  All fields are optional by default in keyword lists, but you can make them required by using `Zoi.required/1`:

      iex> schema = Zoi.keyword([name: Zoi.string() |> Zoi.required()])
      iex> Zoi.parse(schema, [])
      {:error,
       [
         %Zoi.Error{
           code: :required,
           message: "is required",
           issue: {"is required", [key: :name]},
           path: [:name]
         }
       ]}

  ## Flexible keys and values

  You can also define a keyword schema that accepts non structured keys, by just declaring the value type:
    
      iex> schema = Zoi.keyword(Zoi.string())
      iex> Zoi.parse(schema, [a: "hello", b: "world"])
      {:ok, [a: "hello", b: "world"]}
  """
  @doc group: "Complex Types"
  @spec keyword(fields :: keyword(), opts :: options()) :: schema()
  defdelegate keyword(fields, opts \\ []), to: Zoi.Types.Keyword, as: :new

  @doc """
  Defines a struct type schema.
  This type is similar to `Zoi.object/2`, but it is specifically designed to work with Elixir structs.

  ## Example

      defmodule MyApp.User do
        defstruct [:name, :age, :email]
      end

      schema = Zoi.struct(MyApp.User, %{
        name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
        age: Zoi.integer() |> Zoi.min(18) |> Zoi.max(120),
        email: Zoi.email()
      })
      Zoi.parse(schema, %MyApp.User{name: "Alice", age: 30, email: "alice@email.com"})
      #=> {:ok, %MyApp.User{name: "Alice", age: 30, email: "alice@email.com"}}
      Zoi.parse(schema, %{})
      #=> {:error, "invalid type: must be a struct"}

  By default, all fields are required, but you can make them optional by using `Zoi.optional/1`:

      schema = Zoi.struct(MyApp.User, %{
        name: Zoi.string() |> Zoi.optional(),
        age: Zoi.integer() |> Zoi.optional(),
        email: Zoi.email() |> Zoi.optional()
      })
      Zoi.parse(schema, %MyApp.User{name: "Alice"})
      #=> {:ok, %MyApp.User{name: "Alice"}}

  You can also parse maps into structs by enabling the `:coerce` option:
      schema = Zoi.struct(MyApp.User, %{
        name: Zoi.string(),
        age: Zoi.integer(),
        email: Zoi.email()
      }, coerce: true)
      Zoi.parse(schema, %{name: "Alice", age: 30, email: "alice@email.com"})
      #=> {:ok, %MyApp.User{name: "Alice", age: 30, email: "alice@email.com"}}
      # Also with string keys
      Zoi.parse(schema, %{"name" => "Alice", "age" => 30, "email" => "alice@email.com"})
      #=> {:ok, %MyApp.User{name: "Alice", age: 30, email: "alice@email.com"}}


  """
  @doc group: "Complex Types"
  @spec struct(module :: module(), fields :: map(), opts :: options()) :: schema()
  defdelegate struct(module, fields, opts \\ []), to: Zoi.Types.Struct, as: :new

  @doc """
  Extends two object type schemas into one.
  This function merges the fields of two object schemas. If there are overlapping fields, the fields from the second schema will override those from the first.

  ## Example
      iex> user = Zoi.object(%{name: Zoi.string()})
      iex> role = Zoi.object(%{role: Zoi.enum([:admin,:user])})
      iex> user_with_role = Zoi.extend(user, role)
      iex> Zoi.parse(user_with_role, %{name: "Alice", role: :admin})
      {:ok, %{name: "Alice", role: :admin}}
  """
  @doc group: "Complex Types"
  @spec extend(schema1 :: schema(), schema2 :: schema(), opts :: options()) ::
          schema()
  defdelegate extend(schema1, schema2, opts \\ []), to: Zoi.Types.Extend, as: :new

  @doc """
  Defines a map type schema.

  ## Example
      iex> schema = Zoi.map(Zoi.string(), Zoi.integer())
      iex> Zoi.parse(schema, %{"a" => 1, "b" => 2})
      {:ok, %{"a" => 1, "b" => 2}}
      iex> Zoi.parse(schema, %{"a" => "1", "b" => 2})
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected integer",
           issue: {"invalid type: expected integer", [type: :integer]},
           path: ["a"]
         }
       ]}
  """
  @doc group: "Complex Types"
  @spec map(key :: schema(), type :: schema(), opts :: options()) ::
          schema()
  defdelegate map(key, type, opts \\ []), to: Zoi.Types.Map, as: :new

  @doc """
  Defines a map type schema with `Zoi.any()` type.

  This type is the same as creating the following map:
      Zoi.map(Zoi.any(), Zoi.any())
  """
  @doc group: "Complex Types"
  @spec map(opts :: options()) :: schema()
  defdelegate map(opts \\ []), to: Zoi.Types.Map, as: :new

  @doc """
  Defines a tuple type schema.

  Use `Zoi.tuple(fields)` to define a tuple with specific types for each element:

      iex> schema = Zoi.tuple({Zoi.string(), Zoi.integer()})
      iex> Zoi.parse(schema, {"hello", 42})
      {:ok, {"hello", 42}}
      iex> Zoi.parse(schema, {"hello", "world"})
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected integer",
           issue: {"invalid type: expected integer", [type: :integer]},
           path: [1]
         }
       ]}
  """
  @doc group: "Complex Types"
  @spec tuple(fields :: tuple(), opts :: options()) :: schema()
  defdelegate tuple(fields, opts \\ []), to: Zoi.Types.Tuple, as: :new

  @doc """
  Defines a array type schema.

  Use `Zoi.array(elements)` to define an array of a specific type:

      iex> schema = Zoi.array(Zoi.string())
      iex> Zoi.parse(schema, ["hello", "world"])
      {:ok, ["hello", "world"]}
      iex> Zoi.parse(schema, ["hello", 123])
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected string",
           issue: {"invalid type: expected string", [type: :string]},
           path: [1]
         }
       ]}

  Built-in validations for integers include:

      Zoi.gt(5)
      Zoi.gte(5)
      Zoi.lt(2)
      Zoi.lte(2)
      Zoi.min(2) # alias for `Zoi.gte/1`
      Zoi.max(5) # alias for `Zoi.lte/1`
      Zoi.length(5)

  for coercion, you can pass the `:coerce` option and `Zoi` will coerce maps and tuples into the array type:
      iex> schema = Zoi.array(Zoi.integer(), coerce: true)
      iex> Zoi.parse(schema, %{0 => 1, 1 => 2, 2 => 3})
      {:ok, [1, 2, 3]}
      iex> Zoi.parse(schema, {1, 2, 3})
      {:ok, [1, 2, 3]}
  """
  @doc group: "Complex Types"
  @spec array(elements :: schema(), opts :: options()) :: schema()
  def array(elements \\ Zoi.any(), opts \\ []) do
    Zoi.Types.Array.new(elements, opts)
  end

  @doc """
  alias for `Zoi.array/2`
  """
  @doc group: "Complex Types"
  @spec list(elements :: schema(), opts :: options()) :: schema()
  defdelegate list(elements, opts \\ []), to: Zoi.Types.Array, as: :new

  @doc """
  Defines an enum type schema.

  Use `Zoi.enum(values)` to define a schema that accepts only specific values:

      iex> schema = Zoi.enum([:red, :green, :blue])
      iex> Zoi.parse(schema, :red)
      {:ok, :red}
      iex> Zoi.parse(schema, :yellow)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_enum_value,
           message: "invalid enum value: expected one of red, green, blue",
           issue: {"invalid enum value: expected one of %{values}", [type: :enum, values: "red, green, blue"]},
           path: []
         }
       ]}

  You can also specify enum as strings:
      iex> schema = Zoi.enum(["red", "green", "blue"])
      iex> Zoi.parse(schema, "red")
      {:ok, "red"}
      iex> Zoi.parse(schema, "yellow")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_enum_value,
           message: "invalid enum value: expected one of red, green, blue",
           issue: {"invalid enum value: expected one of %{values}", [type: :enum, values: "red, green, blue"]},
           path: []
         }
       ]}

  or with key-value pairs:
      iex> schema = Zoi.enum([red: "Red", green: "Green", blue: "Blue"])
      iex> Zoi.parse(schema, "Red")
      {:ok, :red}
      iex> Zoi.parse(schema, "Yellow")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_enum_value,
           message: "invalid enum value: expected one of Red, Green, Blue",
           issue: {"invalid enum value: expected one of %{values}", [type: :enum, values: "Red, Green, Blue"]},
           path: []
         }
       ]}

  Integer values can also be used:
      iex> schema = Zoi.enum([1, 2, 3])
      iex> Zoi.parse(schema, 1)
      {:ok, 1}
      iex> Zoi.parse(schema, 4)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_enum_value,
           message: "invalid enum value: expected one of 1, 2, 3",
           issue: {"invalid enum value: expected one of %{values}", [type: :enum, values: "1, 2, 3"]},
           path: []
         }
       ]}

  And Integers with key-value pairs also is allowed:
      iex> schema = Zoi.enum([one: 1, two: 2, three: 3])
      iex> Zoi.parse(schema, 1)
      {:ok, :one}
      iex> Zoi.parse(schema, 4)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_enum_value,
           message: "invalid enum value: expected one of 1, 2, 3",
           issue: {"invalid enum value: expected one of %{values}", [type: :enum, values: "1, 2, 3"]},
           path: []
         }
       ]}

  You can also specify the `:coerce` option to allow coercion for both key and value of the enum:
      iex> schema = Zoi.enum([one: 1, two: 2, three: 3], coerce: true)
      iex> Zoi.parse(schema, 1)
      {:ok, :one}
      iex> Zoi.parse(schema, :one)
      {:ok, :one}
      iex> Zoi.parse(schema, "1")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_enum_value,
           message: "invalid enum value: expected one of 1, 2, 3",
           issue: {"invalid enum value: expected one of %{values}", [type: :enum, values: "1, 2, 3"]},
           path: []
         }
       ]}
      iex> Zoi.parse(schema, "one")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_enum_value,
           message: "invalid enum value: expected one of 1, 2, 3",
           issue: {"invalid enum value: expected one of %{values}", [type: :enum, values: "1, 2, 3"]},
           path: []
         }
       ]}
  """
  @doc group: "Complex Types"
  @spec enum(values :: [input()] | keyword(), opts :: options()) :: schema()
  defdelegate enum(values, opts \\ []), to: Zoi.Types.Enum, as: :new

  @doc """
  Defines a date type schema.

  This type is used to validate and parse date values. It will convert the input to a `Date` structure.

  ## Example

      iex> schema = Zoi.date()
      iex> Zoi.parse(schema, ~D[2000-01-01])
      {:ok, ~D[2000-01-01]}
      iex> Zoi.parse(schema, "2000-01-01")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected date",
           issue: {"invalid type: expected date", [type: :date]},
           path: []
         }
       ]}

  You can also specify the `:coerce` option to allow coercion from strings or integers:
      iex> schema = Zoi.date(coerce: true)
      iex> Zoi.parse(schema, "2000-01-01")
      {:ok, ~D[2000-01-01]}
      iex> Zoi.parse(schema, 730_485) # 730_485 is the number of days since epoch
      {:ok, ~D[2000-01-01]}

  """
  @doc group: "Structured Types"
  @spec date(opts :: options()) :: schema()
  defdelegate date(opts \\ []), to: Zoi.Types.Date, as: :new

  @doc """
  Defines a time type schema.

  This type is used to validate and parse time values. It will convert the input to a `Time` structure.

  ## Example

      iex> schema = Zoi.time()
      iex> Zoi.parse(schema, ~T[12:34:56])
      {:ok, ~T[12:34:56]}
      iex> Zoi.parse(schema, "12:34:56")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected time",
           issue: {"invalid type: expected time", [type: :time]},
           path: []
         }
       ]}

  You can also specify the `:coerce` option to allow coercion from strings:
      iex> schema = Zoi.time(coerce: true)
      iex> Zoi.parse(schema, "12:34:56")
      {:ok, ~T[12:34:56]}
  """
  @doc group: "Structured Types"
  @spec time(opts :: options()) :: schema()
  defdelegate time(opts \\ []), to: Zoi.Types.Time, as: :new

  @doc """
  Defines a DateTime type schema.

  This type is used to validate and parse DateTime values. It will convert the input to a `DateTime` structure.

  ## Example
      iex> schema = Zoi.datetime()
      iex> Zoi.parse(schema, ~U[2000-01-01 12:34:56Z])
      {:ok, ~U[2000-01-01 12:34:56Z]}
      iex> Zoi.parse(schema, "2000-01-01T12:34:56Z")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected datetime",
           issue: {"invalid type: expected datetime", [type: :datetime]},
           path: []
         }
       ]}

  You can also specify the `:coerce` option to allow coercion from strings or integers:
      iex> schema = Zoi.datetime(coerce: true)
      iex> Zoi.parse(schema, "2000-01-01T12:34:56Z")
      {:ok, ~U[2000-01-01 12:34:56Z]}
      iex> Zoi.parse(schema, 1_464_096_368) # 1_464_096_368 is the Unix timestamp
      {:ok, ~U[2016-05-24 13:26:08Z]}
  """
  @doc group: "Structured Types"
  @spec datetime(opts :: options()) :: schema()
  defdelegate datetime(opts \\ []), to: Zoi.Types.DateTime, as: :new

  @doc """
  Defines a NaiveDateTime type schema.

  This type is used to validate and parse NaiveDateTime values. It will convert the input to a `NaiveDateTime` structure.

  ## Example

      iex> schema = Zoi.naive_datetime()
      iex> Zoi.parse(schema, ~N[2000-01-01 23:00:07])
      {:ok, ~N[2000-01-01 23:00:07]}
      iex> Zoi.parse(schema, "2000-01-01T12:34:56")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected naive datetime",
           issue: {"invalid type: expected naive datetime", [type: :naive_datetime]},
           path: []
         }
       ]}

  You can also specify the `:coerce` option to allow coercion from strings or integers:
      iex> schema = Zoi.naive_datetime(coerce: true)
      iex> Zoi.parse(schema, "2000-01-01T12:34:56")
      {:ok, ~N[2000-01-01 12:34:56]}
      iex> Zoi.parse(schema, 1) # 1  is the number of days since epoch
      {:ok, ~N[0000-01-01 00:00:01]}
  """
  @doc group: "Structured Types"
  @spec naive_datetime(opts :: options()) :: schema()
  defdelegate naive_datetime(opts \\ []), to: Zoi.Types.NaiveDateTime, as: :new

  if Code.ensure_loaded?(Decimal) do
    @doc """
    Defines a decimal type schema.

    This type is used to validate and parse decimal numbers, which can be useful for financial calculations or precise numeric values.
    It uses the `Decimal` library for handling decimal numbers. It will convert the input to a `Decimal` structure.

    ## Example

        iex> schema = Zoi.decimal()
        iex> Zoi.parse(schema, Decimal.new("123.45"))
        {:ok, Decimal.new("123.45")}
        iex> Zoi.parse(schema, "invalid-decimal")
        {:error,
         [
           %Zoi.Error{
             code: :invalid_type,
             message: "invalid type: expected decimal",
             issue: {"invalid type: expected decimal", [type: :decimal]},
             path: []
           }
         ]}

    You can also specify the `:coerce` option to allow coercion from strings or integers:
        iex> schema = Zoi.decimal(coerce: true)
        iex> Zoi.parse(schema, "123.45")
        {:ok, Decimal.new("123.45")}
        iex> Zoi.parse(schema, 123)
        {:ok, Decimal.new("123")}
    """
    @doc group: "Structured Types"
    @spec decimal(opts :: options()) :: schema()
    defdelegate decimal(opts \\ []), to: Zoi.Types.Decimal, as: :new
  else
    def decimal(_opts \\ []) do
      raise "`Decimal` library is not available. Please add `{:decimal, \"~> 2.0\"}` to your mix.exs dependencies."
    end
  end

  @doc """
  Validates that the string is a valid email format.

  ## Example
      iex> schema = Zoi.email()
      iex> Zoi.parse(schema, "test@test.com")
      {:ok, "test@test.com"}
      iex> {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid-email")
      iex> error.message
      "invalid email format"
      

  It uses a regex pattern to validate the email format, which checks for a standard email structure including local part, domain, and top-level domain:
      ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i

  You can customize the email pattern by `Zoi` built-in options:

      # Regex based on on https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/email
      Zoi.email(pattern: Zoi.Regexes.html5_email())

      # Regex pattern based on RFC 5322 official standard
      Zoi.email(pattern: Zoi.Regexes.rfc5322_email())

      # Regex pattern based on how Phoenix framework validates emails
      Zoi.email(pattern: Zoi.Regexes.simple_email())

      # The default, inspired by the [reasonable email regex}(https://colinhacks.com/essays/reasonable-email-regex)
      Zoi.email(pattern: Zoi.Regexes.email())

  or adding your own custom regex:

      Zoi.email(pattern: ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/)  
  """
  @doc group: "Formats"
  @spec email(opts :: options()) :: schema()
  def email(opts \\ []) do
    regex = Keyword.get(opts, :pattern, Regexes.email())

    Zoi.string()
    |> regex(regex,
      format: :email,
      error: opts[:error],
      internal_message: "invalid email format"
    )
  end

  @doc """
  Validates that the string is a valid UUID format.

  You can specify the UUID version using the `:version` option, which can be one of "v1", "v2", "v3", "v4", "v5", "v6", "v7", or "v8". If no version is specified, it defaults to any valid UUID format.

  ## Example
      iex> schema = Zoi.uuid()
      iex> Zoi.parse(schema, "550e8400-e29b-41d4-a716-446655440000")
      {:ok, "550e8400-e29b-41d4-a716-446655440000"}
      iex> {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid-uuid")
      iex> error.message
      "invalid UUID format"

      iex> schema = Zoi.uuid(version: "v8")
      iex> Zoi.parse(schema, "6d084cef-a067-8e9e-be6d-7c5aefdfd9b4")
      {:ok, "6d084cef-a067-8e9e-be6d-7c5aefdfd9b4"}
  """
  @doc group: "Formats"
  @spec uuid(opts :: options()) :: schema()
  def uuid(opts \\ []) do
    Zoi.string()
    |> regex(Regexes.uuid(opts),
      error: opts[:error],
      internal_message: "invalid UUID format"
    )
  end

  @doc ~S"""
  Defines a URL format validation.

  ## Example

      iex> schema = Zoi.url()
      iex> Zoi.parse(schema, "https://example.com")
      {:ok, "https://example.com"}
      iex> {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "invalid-url")
      iex> error.message
      "invalid format: must be a valid URL"
  """
  @doc group: "Formats"
  @spec url(opts :: options()) :: schema()
  def url(opts \\ []) do
    Zoi.string()
    |> refine({Zoi.Refinements, :refine, [[:url], opts]})
  end

  @doc """
  Validates that the string is a valid IPv4 address.

  ## Example

      iex> schema = Zoi.ipv4()
      iex> Zoi.parse(schema, "127.0.0.1")
      {:ok, "127.0.0.1"}
  """
  @doc group: "Formats"
  @spec ipv4(opts :: options()) :: schema()
  def ipv4(opts \\ []) do
    Zoi.string()
    |> regex(Regexes.ipv4(),
      error: opts[:error],
      internal_message: "invalid IPv4 address"
    )
  end

  @doc """
  Validates that the string is a valid IPv6 address.

  ## Example

      iex> schema = Zoi.ipv6()
      iex> Zoi.parse(schema, "2001:0db8:85a3:0000:0000:8a2e:0370:7334")
      {:ok, "2001:0db8:85a3:0000:0000:8a2e:0370:7334"}
  """
  @doc group: "Formats"
  @spec ipv6(opts :: options()) :: schema()
  def ipv6(opts \\ []) do
    Zoi.string()
    |> regex(Regexes.ipv6(),
      error: opts[:error],
      internal_message: "invalid IPv6 address"
    )
  end

  @doc """
  Validates that the string is a valid hexadecimal format.

  ## Example

      iex> schema = Zoi.hex()
      iex> Zoi.parse(schema, "a3c113")
      {:ok, "a3c113"}
  """
  @doc group: "Formats"
  @spec hex(opts :: options()) :: schema()
  def hex(opts \\ []) do
    Zoi.string()
    |> regex(Regexes.hex(),
      error: opts[:error],
      internal_message: "invalid hex format"
    )
  end

  # Refinements

  @doc """
  Validates that the string has a specific length.
  ## Example

      iex> schema = Zoi.string() |> Zoi.length(5)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "hi")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_length,
            message: "invalid length: must have 5 character(s)",
           issue: {"invalid length: must have %{count} character(s)", [count: 5]},
           path: []
         }
       ]}
  """

  @doc group: "Refinements"
  @spec length(schema :: schema(), length :: non_neg_integer(), opts :: options()) ::
          schema()
  def length(schema, length, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[length: length], opts]})
  end

  @doc ~S"""
  Validates that the input value is within a list of valid literals.

  This refinement can be used with any type and checks if the parsed value
  is a member of the provided list.

  ## Example
      iex> schema = Zoi.string() |> Zoi.one_of(["red", "green", "blue"])
      iex> Zoi.parse(schema, "red")
      {:ok, "red"}
      iex> Zoi.parse(schema, "yellow")
      {:error,
       [
         %Zoi.Error{
           code: :not_in_values,
           message: "invalid value: expected one of red, green, blue",
           issue: {"invalid value: expected one of %{values}", [values: ["red", "green", "blue"]]},
           path: []
         }
       ]}

      iex> schema = Zoi.integer() |> Zoi.one_of([1, 2, 3, 5, 8])
      iex> Zoi.parse(schema, 5)
      {:ok, 5}
      iex> {:error, [%Zoi.Error{code: code}]} = Zoi.parse(schema, 4)
      iex> code
      :not_in_values
  """
  @doc group: "Refinements"
  @spec one_of(schema :: schema(), values :: list(), opts :: options()) :: schema()
  def one_of(schema, values, opts \\ []) when is_list(values) do
    schema
    |> refine({Zoi.Refinements, :refine, [[one_of: values], opts]})
  end

  @doc """
  alias for `Zoi.gte/2`
  """
  @doc group: "Refinements"
  @spec min(schema :: schema(), min :: non_neg_integer(), opts :: options()) :: schema()
  def min(schema, min, opts \\ []) do
    __MODULE__.gte(schema, min, opts)
  end

  @doc """
  Validates that the input is greater than or equal to a value.

  This can be used for strings, integers, floats and numbers.

  ## Example
      iex> schema = Zoi.string() |> Zoi.gte(3)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "hi")
      {:error,
       [
         %Zoi.Error{
           code: :greater_than_or_equal_to,
           message: "too small: must have at least 3 character(s)",
           issue: {"too small: must have at least %{count} character(s)", [count: 3]},
           path: []
         }
       ]}
  """
  @doc group: "Refinements"
  @spec gte(schema :: schema(), min :: non_neg_integer(), opts :: options()) :: schema()
  def gte(schema, gte, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[gte: gte], opts]})
  end

  @doc """
  Validates that the input is greater than a specific value.

  This can be used for strings, integers, floats and numbers.

  ## Example
      iex> schema = Zoi.integer() |> Zoi.gt(2)
      iex> Zoi.parse(schema, 3)
      {:ok, 3}
      iex> Zoi.parse(schema, 2)
      {:error,
       [
         %Zoi.Error{
           code: :greater_than,
           message: "too small: must be greater than 2",
           issue: {"too small: must be greater than %{count}", [count: 2]},
           path: []
         }
       ]}
  """
  @doc group: "Refinements"
  @spec gt(schema :: schema(), gt :: non_neg_integer(), opts :: options()) :: schema()
  def gt(schema, gt, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[gt: gt], opts]})
  end

  @doc """
  alias for `Zoi.lte/2`
  """
  @doc group: "Refinements"
  @spec max(schema :: schema(), max :: non_neg_integer(), opts :: options()) :: schema()
  def max(schema, max, opts \\ []) do
    lte(schema, max, opts)
  end

  @doc """
  Validates that the input is less than or equal to a value.

  This can be used for strings, integers, floats and numbers.

  ## Example
      iex> schema = Zoi.string() |> Zoi.lte(5)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "hello world")
      {:error,
       [
         %Zoi.Error{
           code: :less_than_or_equal_to,
           message: "too big: must have at most 5 character(s)",
           issue: {"too big: must have at most %{count} character(s)", [count: 5]},
           path: []
         }
       ]}
  """
  @doc group: "Refinements"
  @spec lte(schema :: schema(), lte :: non_neg_integer(), opts :: options()) :: schema()
  def lte(schema, lte, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[lte: lte], opts]})
  end

  @doc """
  Validates that the input is less than a specific value.

  This can be used for strings, integers, floats and numbers.

  ## Example
      iex> schema = Zoi.integer() |> Zoi.lt(10)
      iex> Zoi.parse(schema, 5)
      {:ok, 5}
      iex> Zoi.parse(schema, 10)
      {:error,
       [
         %Zoi.Error{
           code: :less_than,
           message: "too big: must be less than 10",
           issue: {"too big: must be less than %{count}", [count: 10]},
           path: []
         }
       ]}
  """
  @doc group: "Refinements"
  @spec lt(schema :: schema(), lt :: non_neg_integer(), opts :: options()) :: schema()
  def lt(schema, lt, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[lt: lt], opts]})
  end

  @doc """
  Validates that the input is a positive number (greater than 0).
  This can be used for integers, floats and numbers.
  ## Example
      iex> schema = Zoi.integer() |> Zoi.positive()
      iex> Zoi.parse(schema, 5)
      {:ok, 5}
      iex> Zoi.parse(schema, 0)
      {:error,
       [
         %Zoi.Error{
           code: :greater_than,
           message: "too small: must be greater than 0",
           issue: {"too small: must be greater than %{count}", [count: 0]},
           path: []
         }
       ]}
  """
  @doc group: "Refinements"
  @spec positive(schema :: schema(), opts :: options()) :: schema()
  def positive(schema, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[gt: 0], opts]})
  end

  @doc """
  Validates that the input is a negative number (less than 0).
  This can be used for integers, floats and numbers.
  ## Example
      iex> schema = Zoi.integer() |> Zoi.negative()
      iex> Zoi.parse(schema, -5)
      {:ok, -5}
      iex> Zoi.parse(schema, 0)
      {:error,
       [
         %Zoi.Error{
           code: :less_than,
           message: "too big: must be less than 0",
           issue: {"too big: must be less than %{count}", [count: 0]},
           path: []
         }
       ]}
  """
  @doc group: "Refinements"
  @spec negative(schema :: schema(), opts :: options()) :: schema()
  def negative(schema, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[lt: 0], opts]})
  end

  @doc """
  Validates that the input is a non-negative number (greater than or equal to 0).
  This can be used for integers, floats and numbers.
  ## Example
      iex> schema = Zoi.integer() |> Zoi.non_negative()
      iex> Zoi.parse(schema, 0)
      {:ok, 0}
      iex> Zoi.parse(schema, -5)
      {:error,
       [
         %Zoi.Error{
           code: :greater_than_or_equal_to,
           message: "too small: must be at least 0",
           issue: {"too small: must be at least %{count}", [count: 0]},
           path: []
         }
       ]}
  """
  @doc group: "Refinements"
  @spec non_negative(schema :: schema(), opts :: options()) :: schema()
  def non_negative(schema, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[gte: 0], opts]})
  end

  @doc """
  Validates that the input matches a given regex pattern.

  ## Example
      iex> schema = Zoi.string() |> Zoi.regex(~r/^\\d+$/)
      iex> Zoi.parse(schema, "12345")
      {:ok, "12345"}
  """
  @doc group: "Refinements"
  @spec regex(schema :: schema(), regex :: Regex.t(), opts :: options()) :: schema()
  def regex(schema, regex, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[regex: regex.source, opts: regex.opts], opts]})
  end

  @doc """
  Validates that a string starts with a specific prefix.

  ## Example

      iex> schema = Zoi.string() |> Zoi.starts_with("hello")
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "world hello")
      iex> error.message
      "invalid format: must start with 'hello'"
  """
  @doc group: "Refinements"
  @spec starts_with(schema :: schema(), prefix :: binary(), opts :: options()) :: schema()
  def starts_with(schema, prefix, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[starts_with: prefix], opts]})
  end

  @doc """
  Validates that a string ends with a specific suffix.
  ## Example

      iex> schema = Zoi.string() |> Zoi.ends_with("world")
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.parse(schema, "hello")
      iex> {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "hello")
      iex> error.message
      "invalid format: must end with 'world'"
  """
  @doc group: "Refinements"
  @spec ends_with(schema :: schema(), suffix :: binary(), opts :: options()) :: schema()
  def ends_with(schema, suffix, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[ends_with: suffix], opts]})
  end

  @doc """
  Validates that a string is in downcase.

  ## Example

      iex> schema = Zoi.string() |> Zoi.downcase()
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "Hello World")
      iex> error.message
      "invalid format: must be lowercase"
  """
  @doc group: "Refinements"
  @spec downcase(schema :: schema(), opts :: options()) :: schema()
  def downcase(schema, opts \\ []) do
    schema
    |> regex(Regexes.downcase(),
      error: opts[:error],
      internal_message: "invalid format: must be lowercase"
    )
  end

  @doc """
  Validates that a string is in upcase.

  ## Example

      iex> schema = Zoi.string() |> Zoi.upcase()
      iex> Zoi.parse(schema, "HELLO")
      {:ok, "HELLO"}
      iex> {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, "Hello")
      iex> error.message
      "invalid format: must be uppercase"
  """
  @doc group: "Refinements"
  @spec upcase(schema :: schema(), opts :: options()) :: schema()
  def upcase(schema, opts \\ []) do
    schema
    |> regex(Regexes.upcase(),
      error: opts[:error],
      internal_message: "invalid format: must be uppercase"
    )
  end

  # Transforms

  @doc """
  Trims whitespace from the beginning and end of a string.

  ## Example

      iex> schema = Zoi.string() |> Zoi.trim()
      iex> Zoi.parse(schema, "  hello world  ")
      {:ok, "hello world"}
  """
  @doc group: "Transforms"
  @spec trim(schema :: schema()) :: schema()
  def trim(schema) do
    schema
    |> transform({Zoi.Transforms, :transform, [[:trim]]})
  end

  @doc """
  Converts a string to lowercase.

  ## Example
      iex> schema = Zoi.string() |> Zoi.to_downcase()
      iex> Zoi.parse(schema, "Hello World")
      {:ok, "hello world"}
  """
  @doc group: "Transforms"
  def to_downcase(schema) do
    schema
    |> transform({Zoi.Transforms, :transform, [[:to_downcase]]})
  end

  @doc """
  Converts a string to uppercase.

  ## Example
      iex> schema = Zoi.string() |> Zoi.to_upcase()
      iex> Zoi.parse(schema, "Hello World")
      {:ok, "HELLO WORLD"}
  """
  @doc group: "Transforms"
  @spec to_upcase(schema :: schema()) :: schema()
  def to_upcase(schema) do
    schema
    |> transform({Zoi.Transforms, :transform, [[:to_upcase]]})
  end

  @doc """
  Converts a schema to a struct of the given module.
  This is useful for transforming parsed data into a specific struct type.

  ## Example

      defmodule User do
        defstruct [:name, :age]
      end

      schema = Zoi.object(%{
        name: Zoi.string(),
        age: Zoi.integer()
      })
      |> Zoi.to_struct(User)

      Zoi.parse(schema, %{name: "Alice", age: 30})
      #=> {:ok, %User{name: "Alice", age: 30}}
  """
  @doc group: "Transforms"
  @spec to_struct(schema :: schema(), struct :: module()) :: schema()
  def to_struct(schema, module) do
    schema
    |> transform({Zoi.Transforms, :transform, [[struct: module]]})
  end

  @doc ~S"""
  Adds a custom validation function to the schema.

  Refinements execute in chain order along with transformations, allowing flexible composition.
  The refinement function validates the data at its position in the chain and should return `:ok` for valid data or `{:error, reason}` for invalid data.

      iex> schema = Zoi.string() |> Zoi.refine(fn value -> 
      ...>   if String.length(value) > 5, do: :ok, else: {:error, "must be longer than 5 characters"}
      ...> end)
      iex> Zoi.parse(schema, "hello")
      {:error,
       [
         %Zoi.Error{
           code: :custom,
           issue: {"must be longer than 5 characters", []},
           message: "must be longer than 5 characters",
           path: []
         }
       ]}
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}

  ## Returning multiple errors

  You can use the context when defining the `Zoi.refine/2` function to return multiple errors.

      iex> schema = Zoi.string() |> Zoi.refine(fn value, ctx ->
      ...>   if String.length(value) < 5 do
      ...>     Zoi.Context.add_error(ctx, "must be longer than 5 characters")
      ...>     |> Zoi.Context.add_error("must be shorter than 10 characters")
      ...>   end
      ...> end)
      iex> Zoi.parse(schema, "hi")
      {:error,
       [
         %Zoi.Error{
           code: :custom,
           issue: {"must be longer than 5 characters", []},
           message: "must be longer than 5 characters",
           path: []
         },
         %Zoi.Error{
           code: :custom,
           issue: {"must be shorter than 10 characters", []},
           message: "must be shorter than 10 characters",
           path: []
         }
       ]}

  ## mfa 

  You can also pass a `mfa` (module, function, args) to the `Zoi.refine/2` function. This is recommended if
  you are declaring schemas during compile time:

      defmodule MySchema do
        use Zoi

        @schema Zoi.string() |> Zoi.refine({__MODULE__, :validate, []})

        def validate(value, opts \\ []) do
          if String.length(value) > 5 do
            :ok
          else 
            {:error, "must be longer than 5 characters"}
          end
        end
      end

  Since during the module compilation, anonymous functions are not available, you can use the `mfa` option to pass a module, function and arguments.
  The `opts` argument is mandatory, this is where the `ctx` is passed to the function and you can leverage the `Zoi.Context` to add extra errors.
  In general, most cases the `:ok` or `{:error, reason}` returns will be enough. Use the context only if you need extra errors or modify the context in some way.
  """
  @doc group: "Extensions"
  @spec refine(schema :: schema(), fun :: refinement()) :: schema()
  def refine(%Zoi.Types.Union{schemas: schemas} = schema, fun) do
    schemas =
      Enum.map(schemas, fn sub_schema ->
        refine(sub_schema, fun)
      end)

    %{schema | schemas: schemas}
  end

  def refine(%Zoi.Types.Intersection{schemas: schemas} = schema, fun) do
    schemas =
      Enum.map(schemas, fn sub_schema ->
        refine(sub_schema, fun)
      end)

    %{schema | schemas: schemas}
  end

  def refine(schema, fun) do
    update_in(schema.meta.effects, fn effects ->
      effects ++ [{:refine, fun}]
    end)
  end

  @doc """
  Adds a transformation function to the schema.

  Transformations execute in chain order along with refinements, allowing flexible composition.
  A transform modifies the data and passes the result to the next effect in the chain.

  ## Example

      iex> schema = Zoi.string() |> Zoi.transform(fn value ->
      ...>   {:ok, String.trim(value)}
      ...> end)
      iex> Zoi.parse(schema, "  hello world  ")
      {:ok, "hello world"}

  You can also use `mfa` (module, function, args) to pass a transformation function:

      iex> defmodule MyTransforms do
      ...>   def trim(value, _opts) do
      ...>     {:ok, String.trim(value)}
      ...>   end
      ...> end
      iex> schema = Zoi.string() |> Zoi.transform({MyTransforms, :trim, []})
      iex> Zoi.parse(schema, "  hello world  ")
      {:ok, "hello world"}

  This is useful if you are defining schemas at compile time, where anonymous functions are not available.
  The `opts` argument is mandatory, this is where the `ctx` is passed to the function and you can leverage the `Zoi.Context` to add extra errors.
  In general, most cases the `{:ok, value}` or `{:error, reason}` returns will be enough. Use the context only if you need extra errors or modify the context in
  some way.

  ## Using context for validation

  You can use the context when defining the `Zoi.transform/2` function to return multiple errors.

      iex> schema = Zoi.string() |> Zoi.transform(fn value, ctx ->
      ...>   if String.length(value) < 5 do
      ...>     Zoi.Context.add_error(ctx, "must be longer than 5 characters")
      ...>     |> Zoi.Context.add_error("must be shorter than 10 characters")
      ...>   else
      ...>     {:ok, String.trim(value)}
      ...>   end
      ...> end)
      iex> Zoi.parse(schema, "hi")
      {:error,
       [
         %Zoi.Error{
           code: :custom,
           issue: {"must be longer than 5 characters", []},
           message: "must be longer than 5 characters",
           path: []
         },
         %Zoi.Error{
           code: :custom,
           issue: {"must be shorter than 10 characters", []},
           message: "must be shorter than 10 characters",
           path: []
         }
       ]}

  The `ctx` is a `Zoi.Context` struct that contains information about the current parsing context, including the path, options, and any errors that have been added so far.
  """
  @doc group: "Extensions"
  @spec transform(schema :: schema(), fun :: transform()) :: schema()
  def transform(%Zoi.Types.Union{schemas: schemas} = schema, fun) do
    schemas =
      Enum.map(schemas, fn sub_schema ->
        transform(sub_schema, fun)
      end)

    %{schema | schemas: schemas}
  end

  def transform(%Zoi.Types.Intersection{schemas: schemas} = schema, fun) do
    schemas =
      Enum.map(schemas, fn sub_schema ->
        transform(sub_schema, fun)
      end)

    %{schema | schemas: schemas}
  end

  def transform(schema, fun) do
    update_in(schema.meta.effects, fn effects ->
      effects ++ [{:transform, fun}]
    end)
  end
end
