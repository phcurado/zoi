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
      {:error, [%Zoi.Error{message: "invalid type: must be a string"}]}

  If you need coercion, you can enable it by passing the `:coerce` option:

      iex> Zoi.string(coerce: true) |> Zoi.parse(123)
      {:ok, "123"}

  ## Custom errors

  You can customize parsing error messages the primitive types by passing the `error` option:

      iex> schema = Zoi.integer(error: "must be a number")
      iex> Zoi.parse(schema, "a")
      {:error, [%Zoi.Error{message: "must be a number"}]}
  """

  alias Zoi.Regexes
  alias Zoi.Types.Meta

  @type input :: any()
  @type result :: {:ok, any()} | {:error, [Zoi.Error.t() | binary()]}
  @type options :: keyword()
  @type refinement ::
          {module(), atom(), [any()]} | (Zoi.Type.t(), Zoi.input() -> :ok | {:error, binary()})
  @type transform ::
          {module(), atom(), [any()]}
          | (Zoi.Type.t(), Zoi.input() -> {:ok, Zoi.input()} | {:error, binary()} | Zoi.input())

  @doc """
  Parse input data against a schema.
  Accepts optional `coerce: true` option to enable coercion.
  ## Examples

      iex> schema = Zoi.string() |> Zoi.min(2) |> Zoi.max(100)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "h")
      {:error, [%Zoi.Error{message: "too small: must have at least 2 characters"}]}
      iex> Zoi.parse(schema, 123, coerce: true)
      {:ok, "123"}
  """
  @doc group: "Parsing"
  @spec parse(schema :: Zoi.Type.t(), input :: input(), opts :: options) :: result()
  def parse(schema, input, opts \\ []) do
    ctx = Keyword.get(opts, :ctx, Zoi.Context.new(schema, input))
    opts = Keyword.put_new(opts, :ctx, ctx)

    with {:ok, result} <- Zoi.Type.parse(schema, input, opts),
         ctx = Zoi.Context.add_parsed(ctx, result),
         {:ok, result} <- Meta.run_transforms(ctx),
         ctx = Zoi.Context.add_parsed(ctx, result),
         {:ok, _refined_result} <- Meta.run_refinements(ctx) do
      {:ok, result}
    else
      {:error, error} ->
        ctx = Zoi.Context.add_error(ctx, error)
        {:error, ctx.errors}
    end
  end

  # Types
  @doc """
  Defines a string type schema.

  ## Example

  Zoi provides built-in validations for strings, such as:

      Zoi.gt(100)
      Zoi.gte(100)
      Zoi.lt(2)
      Zoi.lte(2)
      Zoi.min(2) # alias for `Zoi.gte(2)`
      Zoi.max(100) # alias for `Zoi.lte(100)`
      Zoi.starts_with("hello")
      Zoi.ends_with("world")
      Zoi.length(5)
      Zoi.regex(~r/^[a-zA-Z]+$/)

  Additionally it can perform data transformation:
      Zoi.string()
      |> Zoi.trim()
      |> Zoi.to_downcase()
      |> Zoi.to_uppercase()
  """
  @doc group: "Basic Types"
  defdelegate string(opts \\ []), to: Zoi.Types.String, as: :new

  @doc """
  Defines a number type schema.

  ## Example

      iex> shema = Zoi.integer()
      iex> Zoi.parse(shema, 42)
      {:ok, 42}

  Built-in validations for integers include:

      Zoi.min(0)
      Zoi.max(100)
  """
  @doc group: "Basic Types"
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
  """
  @doc group: "Basic Types"
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
      {:error, [%Zoi.Error{message: "invalid type: must be a string boolean"}]}
      iex> Zoi.parse(schema, "true")
      {:ok, true}
  """
  @doc group: "Basic Types"
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
  defdelegate any(opts \\ []), to: Zoi.Types.Any, as: :new

  @doc """
  Defines an atom type schema.

  ## Examples
      iex> schema = Zoi.atom()
      iex> Zoi.parse(schema, :atom)
      {:ok, :atom}
      iex> Zoi.parse(schema, "not_an_atom")
      {:error, [%Zoi.Error{message: "invalid type: must be an atom"}]}
  """
  @doc group: "Basic Types"
  defdelegate atom(opts \\ []), to: Zoi.Types.Atom, as: :new

  @doc """
  Makes the schema optional for the `Zoi.object/2` type.

  ## Example

      iex> schema = Zoi.object(%{name: Zoi.string() |> Zoi.optional()})
      iex> Zoi.parse(schema, %{})
      {:ok, %{}}
  """
  @doc group: "Encapsulated Types"
  defdelegate optional(opts \\ []), to: Zoi.Types.Optional, as: :new

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
  defdelegate nullable(opts \\ []), to: Zoi.Types.Nullable, as: :new

  @doc """
  Creates a default value for the schema.

  This allows you to specify a default value that will be used if the input is `nil` or not provided.

  ## Example
      iex> schema = Zoi.string() |> Zoi.default("default value")
      iex> Zoi.parse(schema, nil)
      {:ok, "default value"}

  """
  @doc group: "Encapsulated Types"
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
      {:error, [%Zoi.Error{message: "invalid type: must be an integer"}]}

  This type also allows to define validations for each type in the union:

      iex> schema = Zoi.union([
      ...>   Zoi.string() |> Zoi.min(2),
      ...>   Zoi.integer() |> Zoi.min(0)
      ...> ])
      iex> Zoi.parse(schema, "h") # fails on string and try to parse as integer
      {:error, [%Zoi.Error{message: "invalid type: must be an integer"}]}
      iex> Zoi.parse(schema, -1)
      {:error, [%Zoi.Error{message: "too small: must be at least 0"}]}

  If you define the validation on the union itself, it will apply to all types in the union:

      iex> schema = Zoi.union([
      ...>   Zoi.string(),
      ...>   Zoi.integer()
      ...> ]) |> Zoi.min(3)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, 2)
      {:error, [%Zoi.Error{message: "too small: must be at least 3"}]}
  """
  @doc group: "Encapsulated Types"
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
      {:error, [%Zoi.Error{message: "too big: must have at most 5 characters"}]}
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
      {:error, [%Zoi.Error{message: "too small: must have at least 3 characters"}]}
  """
  @doc group: "Encapsulated Types"
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
      {:error, [%Zoi.Error{message: "unrecognized key: 'age'"}]}


  ## Nullable vs Optional fields

  The `Zoi.optional/1` function makes a field optional, meaning it can be omitted from the input data. If the field is not present, it will not be included in the parsed result.
  The `Zoi.nullable/1` function allows a field to be `nil`, meaning it can be explicitly set to `nil` in the input data. If the field is set to `nil`, it will be included in the parsed result as `nil`.

      iex> schema = Zoi.object(%{name: Zoi.string() |> Zoi.optional(), age: Zoi.integer() |> Zoi.nullable()})
      iex> Zoi.parse(schema, %{name: "Alice", age: nil})
      {:ok, %{name: "Alice", age: nil}}
      iex> Zoi.parse(schema, %{name: "Alice"})
      {:error, [%Zoi.Error{message: "is required", path: [:age]}]}

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
  """
  @doc group: "Complex Types"
  defdelegate object(fields, opts \\ []), to: Zoi.Types.Object, as: :new

  @doc """
  Defines a map type schema.

  ## Example
      iex> schema = Zoi.map(Zoi.string(), Zoi.integer())
      iex> Zoi.parse(schema, %{"a" => 1, "b" => 2})
      {:ok, %{"a" => 1, "b" => 2}}
      iex> Zoi.parse(schema, %{"a" => "1", "b" => 2})
      {:error, [%Zoi.Error{message: "invalid type: must be an integer", path: ["a"]}]}
  """
  @doc group: "Complex Types"
  defdelegate map(key, type, opts \\ []), to: Zoi.Types.Map, as: :new

  @doc """
  Defines a map type schema with `Zoi.any()` type.

  This type is the same as creating the following map:
      Zoi.map(Zoi.any(), Zoi.any())
  """
  @doc group: "Complex Types"
  defdelegate map(opts \\ []), to: Zoi.Types.Map, as: :new

  @doc """
  Defines a tuple type schema.

  Use `Zoi.tuple(fields)` to define a tuple with specific types for each element:

      iex> schema = Zoi.tuple({Zoi.string(), Zoi.integer()})
      iex> Zoi.parse(schema, {"hello", 42})
      {:ok, {"hello", 42}}
      iex> Zoi.parse(schema, {"hello", "world"})
      {:error, [%Zoi.Error{message: "invalid type: must be an integer", path: [1]}]}
  """
  @doc group: "Complex Types"
  defdelegate tuple(fields, opts \\ []), to: Zoi.Types.Tuple, as: :new

  @doc """
  Defines a array type schema.

  Use `Zoi.array(elements)` to define an array of a specific type:

      iex> schema = Zoi.array(Zoi.string())
      iex> Zoi.parse(schema, ["hello", "world"])
      {:ok, ["hello", "world"]}
      iex> Zoi.parse(schema, ["hello", 123])
      {:error, [%Zoi.Error{message: "invalid type: must be a string", path: [1]}]}

  Built-in validations for integers include:

      Zoi.gt(5)
      Zoi.gte(5)
      Zoi.lt(2)
      Zoi.lte(2)
      Zoi.min(2) # alias for `Zoi.gte/1`
      Zoi.max(5) # alias for `Zoi.lte/1`
      Zoi.length(5)
  """
  @doc group: "Complex Types"
  defdelegate array(elements, opts \\ []), to: Zoi.Types.Array, as: :new

  @doc """
  Defines an enum type schema.

  Use `Zoi.enum(values)` to define a schema that accepts only specific values:

      iex> schema = Zoi.enum([:red, :green, :blue])
      iex> Zoi.parse(schema, :red)
      {:ok, :red}
      iex> Zoi.parse(schema, :yellow)
      {:error, [%Zoi.Error{message: "invalid option, must be one of: red, green, blue"}]}

  You can also specify enum as strings:
      iex> schema = Zoi.enum(["red", "green", "blue"])
      iex> Zoi.parse(schema, "red")
      {:ok, "red"}
      iex> Zoi.parse(schema, "yellow")
      {:error, [%Zoi.Error{message: "invalid option, must be one of: red, green, blue"}]}

  or with key-value pairs:
      iex> schema = Zoi.enum([red: "Red", green: "Green", blue: "Blue"])
      iex> Zoi.parse(schema, "Red")
      {:ok, :red}
      iex> Zoi.parse(schema, "Yellow")
      {:error, [%Zoi.Error{message: "invalid option, must be one of: Red, Green, Blue"}]}

  Integer values can also be used:
      iex> schema = Zoi.enum([1, 2, 3])
      iex> Zoi.parse(schema, 1)
      {:ok, 1}
      iex> Zoi.parse(schema, 4)
      {:error, [%Zoi.Error{message: "invalid option, must be one of: 1, 2, 3"}]}

  And Integers with key-value pairs also is allowed:
      iex> schema = Zoi.enum([one: 1, two: 2, three: 3])
      iex> Zoi.parse(schema, 1)
      {:ok, :one}
      iex> Zoi.parse(schema, 4)
      {:error, [%Zoi.Error{message: "invalid value for enum"}]}
      {:error, [%Zoi.Error{message: "invalid option, must be one of: 1, 2, 3"}]}
  """
  @doc group: "Complex Types"
  defdelegate enum(values, opts \\ []), to: Zoi.Types.Enum, as: :new

  @doc """
  Defines a date type schema.

  This type is used to validate and parse date values. It will convert the input to a `Date` structure.

  ## Example

      iex> schema = Zoi.date()
      iex> Zoi.parse(schema, ~D[2000-01-01])
      {:ok, ~D[2000-01-01]}
      iex> Zoi.parse(schema, "2000-01-01")
      {:error, [%Zoi.Error{message: "invalid type: must be a date"}]}

  You can also specify the `:coerce` option to allow coercion from strings or integers:
      iex> schema = Zoi.date(coerce: true)
      iex> Zoi.parse(schema, "2000-01-01")
      {:ok, ~D[2000-01-01]}
      iex> Zoi.parse(schema, 730_485) # 730_485 is the number of days since epoch
      {:ok, ~D[2000-01-01]}

  """
  @doc group: "Structured Types"
  defdelegate date(opts \\ []), to: Zoi.Types.Date, as: :new

  @doc """
  Defines a time type schema.

  This type is used to validate and parse time values. It will convert the input to a `Time` structure.

  ## Example

      iex> schema = Zoi.time()
      iex> Zoi.parse(schema, ~T[12:34:56])
      {:ok, ~T[12:34:56]}
      iex> Zoi.parse(schema, "12:34:56")
      {:error, [%Zoi.Error{message: "invalid type: must be a time"}]}

  You can also specify the `:coerce` option to allow coercion from strings:
      iex> schema = Zoi.time(coerce: true)
      iex> Zoi.parse(schema, "12:34:56")
      {:ok, ~T[12:34:56]}
  """
  @doc group: "Structured Types"
  defdelegate time(opts \\ []), to: Zoi.Types.Time, as: :new

  @doc """
  Defines a DateTime type schema.

  This type is used to validate and parse DateTime values. It will convert the input to a `DateTime` structure.

  ## Example
      iex> schema = Zoi.datetime()
      iex> Zoi.parse(schema, ~U[2000-01-01 12:34:56Z])
      {:ok, ~U[2000-01-01 12:34:56Z]}
      iex> Zoi.parse(schema, "2000-01-01T12:34:56Z")
      {:error, [%Zoi.Error{message: "invalid type: must be a datetime"}]}

  You can also specify the `:coerce` option to allow coercion from strings or integers:
      iex> schema = Zoi.datetime(coerce: true)
      iex> Zoi.parse(schema, "2000-01-01T12:34:56Z")
      {:ok, ~U[2000-01-01 12:34:56Z]}
      iex> Zoi.parse(schema, 1_464_096_368) # 1_464_096_368 is the Unix timestamp
      {:ok, ~U[2016-05-24 13:26:08Z]}
  """
  @doc group: "Structured Types"
  defdelegate datetime(opts \\ []), to: Zoi.Types.DateTime, as: :new

  @doc """
  Defines a NaiveDateTime type schema.

  This type is used to validate and parse NaiveDateTime values. It will convert the input to a `NaiveDateTime` structure.

  ## Example

      iex> schema = Zoi.naive_datetime()
      iex> Zoi.parse(schema, ~N[2000-01-01 23:00:07])
      {:ok, ~N[2000-01-01 23:00:07]}
      iex> Zoi.parse(schema, "2000-01-01T12:34:56")
      {:error, [%Zoi.Error{message: "invalid type: must be a naive datetime"}]}

  You can also specify the `:coerce` option to allow coercion from strings or integers:
      iex> schema = Zoi.naive_datetime(coerce: true)
      iex> Zoi.parse(schema, "2000-01-01T12:34:56")
      {:ok, ~N[2000-01-01 12:34:56]}
      iex> Zoi.parse(schema, 1) # 1  is the number of days since epoch
      {:ok, ~N[0000-01-01 00:00:01]}
  """
  @doc group: "Structured Types"
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
        {:error, [%Zoi.Error{message: "invalid type: must be a decimal"}]}

    You can also specify the `:coerce` option to allow coercion from strings or integers:
        iex> schema = Zoi.decimal(coerce: true)
        iex> Zoi.parse(schema, "123.45")
        {:ok, Decimal.new("123.45")}
        iex> Zoi.parse(schema, 123)
        {:ok, Decimal.new("123")}
    """
    @doc group: "Structured Types"
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
      iex> Zoi.parse(schema, "invalid-email")
      {:error, [%Zoi.Error{message: "invalid email format"}]}

  It uses a regex pattern to validate the email format, which checks for a standard email structure including local part, domain, and top-level domain:
      ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i
  """
  @doc group: "Formats"
  @spec email() :: Zoi.Type.t()
  def email() do
    Zoi.string()
    |> regex(Regexes.email(),
      message: "invalid email format"
    )
  end

  @doc """
  Validates that the string is a valid UUID format.

  You can specify the UUID version using the `:version` option, which can be one of "v1", "v2", "v3", "v4", "v5", "v6", "v7", or "v8". If no version is specified, it defaults to any valid UUID format.

  ## Example
      iex> schema = Zoi.uuid()
      iex> Zoi.parse(schema, "550e8400-e29b-41d4-a716-446655440000")
      {:ok, "550e8400-e29b-41d4-a716-446655440000"}
      iex> Zoi.parse(schema, "invalid-uuid")
      {:error, [%Zoi.Error{message: "invalid UUID format"}]}

      iex> schema = Zoi.uuid(version: "v8")
      iex> Zoi.parse(schema, "6d084cef-a067-8e9e-be6d-7c5aefdfd9b4")
      {:ok, "6d084cef-a067-8e9e-be6d-7c5aefdfd9b4"}
  """
  @doc group: "Formats"
  @spec uuid(opts :: keyword()) :: Zoi.Type.t()
  def uuid(opts \\ []) do
    Zoi.string()
    |> regex(Regexes.uuid(opts),
      message: "invalid UUID format"
    )
  end

  @doc """
  Defines a URL format validation.

  ## Example

      iex> schema = Zoi.url()
      iex> Zoi.parse(schema, "https://example.com")
      {:ok, "https://example.com"}
      iex> Zoi.parse(schema, "invalid-url")
      {:error, [%Zoi.Error{message: "invalid URL"}]}

  """
  @doc group: "Formats"
  def url() do
    Zoi.string()
    |> regex(Regexes.url(),
      message: "invalid URL"
    )
  end

  @doc """
  Validates that the string is a valid IPv4 address.

  ## Example

      iex> schema = Zoi.ipv4()
      iex> Zoi.parse(schema, "127.0.0.1")
      {:ok, "127.0.0.1"}
  """
  @doc group: "Formats"
  def ipv4() do
    Zoi.string()
    |> regex(Regexes.ipv4(),
      message: "invalid IPv4 address"
    )
  end

  @doc """
  Validates that the string is a valid IPv6 address.
  ## Example

      iex> schema = Zoi.ipv6()
      iex> Zoi.parse(schema, "2001:0db8:85a3:0000:0000:8a2e:0370:7334")
      {:ok, "2001:0db8:85a3:0000:0000:8a2e:0370:7334"}
      iex> Zoi.parse(schema, "invalid-ipv6")
      {:error, [%Zoi.Error{message: "invalid IPv6 address"}]}
  """
  @doc group: "Formats"
  def ipv6() do
    Zoi.string()
    |> regex(Regexes.ipv6(),
      message: "invalid IPv6 address"
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
      {:error, [%Zoi.Error{message: "invalid length: must have 5 characters"}]}
  """

  @doc group: "Refinements"
  @spec length(schema :: Zoi.Type.t(), length :: non_neg_integer(), opts :: options()) ::
          Zoi.Type.t()
  def length(schema, length, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[length: length], opts]})
  end

  @doc """
  alias for `Zoi.gte/2`
  """
  @doc group: "Refinements"
  @spec min(schema :: Zoi.Type.t(), min :: non_neg_integer(), opts :: options()) :: Zoi.Type.t()
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
      {:error, [%Zoi.Error{message: "too small: must have at least 3 characters"}]}
  """
  @doc group: "Refinements"
  @spec gte(schema :: Zoi.Type.t(), min :: non_neg_integer(), opts :: options()) :: Zoi.Type.t()
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
      {:error, [%Zoi.Error{message: "too small: must be greater than 2"}]}
  """
  @doc group: "Refinements"
  @spec gt(schema :: Zoi.Type.t(), gt :: non_neg_integer(), opts :: options()) :: Zoi.Type.t()
  def gt(schema, gt, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[gt: gt], opts]})
  end

  @doc """
  alias for `Zoi.lte/2`
  """
  @doc group: "Refinements"
  @spec max(schema :: Zoi.Type.t(), max :: non_neg_integer(), opts :: options()) :: Zoi.Type.t()
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
      {:error, [%Zoi.Error{message: "too big: must have at most 5 characters"}]}
  """
  @doc group: "Refinements"
  @spec lte(schema :: Zoi.Type.t(), lte :: non_neg_integer(), opts :: options()) :: Zoi.Type.t()
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
      {:error, [%Zoi.Error{message: "too big: must be less than 10"}]}
  """
  @doc group: "Refinements"
  @spec lt(schema :: Zoi.Type.t(), lt :: non_neg_integer(), opts :: options()) :: Zoi.Type.t()
  def lt(schema, lt, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[lt: lt], opts]})
  end

  @doc """
  Validates that the input matches a given regex pattern.

  ## Example
      iex> schema = Zoi.string() |> Zoi.regex(~r/^\\d+$/)
      iex> Zoi.parse(schema, "12345")
      {:ok, "12345"}
  """
  @doc group: "Refinements"
  @spec regex(schema :: Zoi.Type.t(), regex :: Regex.t(), opts :: options()) :: Zoi.Type.t()
  def regex(schema, regex, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[regex: regex], opts]})
  end

  @doc """
  Validates that a string starts with a specific prefix.

  ## Example

      iex> schema = Zoi.string() |> Zoi.starts_with("hello")
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.parse(schema, "world hello")
      {:error, [%Zoi.Error{message: "invalid string: must start with 'hello'"}]}
  """
  @doc group: "Refinements"
  @spec starts_with(schema :: Zoi.Type.t(), prefix :: binary(), opts :: options()) :: Zoi.Type.t()
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
      {:error, [%Zoi.Error{message: "invalid string: must end with 'world'"}]}
  """
  @doc group: "Refinements"
  @spec ends_with(schema :: Zoi.Type.t(), suffix :: binary(), opts :: options()) :: Zoi.Type.t()
  def ends_with(schema, suffix, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[ends_with: suffix], opts]})
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
  @spec trim(schema :: Zoi.Type.t()) :: Zoi.Type.t()
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
  @spec to_upcase(schema :: Zoi.Type.t()) :: Zoi.Type.t()
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
  @spec to_struct(schema :: Zoi.Type.t(), struct :: module()) :: Zoi.Type.t()
  def to_struct(schema, module) do
    schema
    |> transform({Zoi.Transforms, :transform, [[struct: module]]})
  end

  @doc ~S"""
  Adds a custom validation function to the schema.

  This function will be called with the input data and options, and should return `:ok` for valid data or `{:error, reason}` for invalid data.

      iex> schema = Zoi.string() |> Zoi.refine(fn value -> 
      ...>   if String.length(value) > 5, do: :ok, else: {:error, "must be longer than 5 characters"}
      ...> end)
      iex> Zoi.parse(schema, "hello")
      {:error, [%Zoi.Error{message: "must be longer than 5 characters"}]}
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
      {:error, [
        %Zoi.Error{message: "must be longer than 5 characters"},
        %Zoi.Error{message: "must be shorter than 10 characters"}
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
  @spec refine(schema :: Zoi.Type.t(), fun :: refinement()) :: Zoi.Type.t()
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
    update_in(schema.meta.refinements, fn transforms ->
      transforms ++ [fun]
    end)
  end

  @doc """
  Adds a transformation function to the schema.

  This function will be applied to the input data after parsing but before validations.

  ## Example

      iex> schema = Zoi.string() |> Zoi.transform(fn value ->
      ...>   {:ok, String.trim(value)}
      ...> end)
      iex> Zoi.parse(schema, "  hello world  ")
      {:ok, "hello world"}
  """
  @doc group: "Extensions"
  @spec transform(schema :: Zoi.Type.t(), fun :: transform()) :: Zoi.Type.t()
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
    update_in(schema.meta.transforms, fn transforms ->
      transforms ++ [fun]
    end)
  end

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

  @spec prettify_errors([Zoi.Error.t() | binary()]) :: binary()
  def prettify_errors(errors) when is_list(errors) do
    Enum.reduce(errors, "", fn error, acc ->
      acc <> prettify_error(error)
    end)
  end

  defp prettify_error(%Zoi.Error{message: message, path: []}) do
    prettify_error(message)
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

    prettify_error("#{message}, at #{path_str}")
  end

  defp prettify_error(error) when is_binary(error) do
    error <> "\n"
  end
end
