defmodule Zoi do
  @moduledoc """
  `Zoi` is a schema validation library for Elixir, designed to provide a simple and flexible way to define and validate data.

  It allows you to create schemas for various data types, including strings, integers, booleans, and complex objects, with built-in support for validations like minimum and maximum values, regex patterns, and email formats.

      user = Zoi.object(%{
        name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
        age: Zoi.integer() |> Zoi.min(18) |> Zoi.max(120),
        email: Zoi.string() |> Zoi.email()
      })

      Zoi.parse(user, %{
        name: "Alice",
        age: 30,
        email: "alice@email.com"
      })
      # {:ok, %{name: "Alice", age: 30, email: "alice@email.com"}}

  ## Schemas
  `Zoi` schemas are defined using a set of functions that create types and validations.

  Primitive types:

      Zoi.string()
      Zoi.integer()
      Zoi.float()
      Zoi.number()
      Zoi.boolean()

  Encapsulated types:

      Zoi.optional(inner_type)
      Zoi.default(inner_type, default_value)
      Zoi.union(fields)

  Complex types:
      Zoi.object(fields)
      Zoi.enum(values)
      Zoi.array(element_type)
      Zoi.tuple(element_type)

  ## Coercion
  By default, `Zoi` will not attempt to infer input data to match the expected type. For example, if you define a schema that expects a string, passing an integer will result in an error.
      iex> Zoi.string() |> Zoi.parse(123)
      {:error, [%Zoi.Error{message: "invalid string type"}]}

  If you need coercion, you can enable it by passing the `:coerce` option:

      iex> Zoi.string(coerce: true) |> Zoi.parse(123)
      {:ok, "123"}
  """

  alias Zoi.Types.Meta

  @type input :: any()
  @type result :: {:ok, any()} | {:error, [Zoi.Error.t() | binary()]}
  @type options :: keyword()

  @doc """
  Parse input data against a schema.
  Accepts optional `coerce: true` option to enable coercion.
  ## Examples

      iex> schema = Zoi.string() |> Zoi.min(2) |> Zoi.max(100)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}

      iex> Zoi.parse(schema, "hi")
      {:error, [%Zoi.Error{message: "minimum length is 2"}]}

      iex> Zoi.parse(schema, 123, coerce: true)
      {:ok, "123"}
  """
  @doc group: "Parsing"
  @spec parse(schema :: Zoi.Type.t(), input :: input(), opts :: options) :: result()
  def parse(schema, input, opts \\ []) do
    with {:ok, result} <- Zoi.Type.parse(schema, input, opts),
         {:ok, _refined_result} <- Meta.run_refinements(schema, result),
         {:ok, result} <- Meta.run_transforms(schema, result) do
      {:ok, result}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, Zoi.Errors.add_error(reason)}

      {:error, error} ->
        {:error, error}
    end
  end

  # Types
  @doc """
  Defines a string type schema.

  ## Example

  Zoi provides built-in validations for strings, such as:

      Zoi.min(2)
      Zoi.max(100)
      Zoi.length(5)
      Zoi.regex(~r/^[a-zA-Z]+$/)

  Additionally it can perform data transformation:
      Zoi.string()
      |> Zoi.trim()
      |> Zoi.downcase()
      |> Zoi.uppercase()

  Zoi also supports validating formats:

      Zoi.email()
      # pattern ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i

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
  Makes the schema optional for the `Zoi.object/2` type.

  ## Example

      iex> schema = Zoi.object(%{name: Zoi.string() |> Zoi.optional()})
      iex> Zoi.parse(schema, %{})
      {:ok, %{}}
  """
  @doc group: "Encapsulated Types"
  defdelegate optional(opts \\ []), to: Zoi.Types.Optional, as: :new

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
      {:error, [%Zoi.Error{message: "invalid type for union"}]}

  This type also allows to define validations for each type in the union:

      iex> schema = Zoi.union([
      ...>   Zoi.string() |> Zoi.min(2),
      ...>   Zoi.integer() |> Zoi.min(0)
      ...> ])
      iex> Zoi.parse(schema, "hi")
      {:error, [%Zoi.Error{message: "minimum length is 2"}]}
      iex> Zoi.parse(schema, -1)
      {:error, [%Zoi.Error{message: "minimum value is 0"}]}

  If you define the validation on the union itself, it will apply to all types in the union:

      iex> schema = Zoi.union([
      ...>   Zoi.string(),
      ...>   Zoi.integer()
      ...> ]) |> Zoi.min(3)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, 2)
      {:error, [%Zoi.Error{message: "minimum value is 3"}]}
  """
  @doc group: "Encapsulated Types"
  defdelegate union(fields, opts \\ []), to: Zoi.Types.Union, as: :new

  @doc """
  Defines a object type schema.

  Use `Zoi.object(fields)` to define complex objects with nested schemas:

      user_schema = Zoi.object(%{
        name: Zoi.string() |> Zoi.min(2) |> Zoi.max(100),
        age: Zoi.integer() |> Zoi.min(18) |> Zoi.max(120),
        email: Zoi.string() |> Zoi.email()
      })

      iex> Zoi.parse(user_schema, %{name: "Alice", age: 30, email: "alice@email.com"})
      {:ok, %{name: "Alice", age: 30, email: "alice@email.com"}}
  """
  @doc group: "Complex Types"
  defdelegate object(fields, opts \\ []), to: Zoi.Types.Object, as: :new

  @doc """
  Defines an enum type schema.
  Use `Zoi.enum(values)` to define a schema that accepts only specific values:

      iex> schema = Zoi.enum([:red, :green, :blue])
      iex> Zoi.parse(schema, :red)
      {:ok, :red}
      iex> Zoi.parse(schema, :yellow)
      {:error, [%Zoi.Error{message: "invalid value for enum"}]}

  You can also specify enum as strings:
      iex> schema = Zoi.enum(["red", "green", "blue"])
      iex> Zoi.parse(schema, "red")
      {:ok, "red"}
      iex> Zoi.parse(schema, "yellow")
      {:error, [%Zoi.Error{message: "invalid value for enum"}]}

  or with key-value pairs:
      iex> schema = Zoi.enum([red: "Red", green: "Green", blue: "Blue"])
      iex> Zoi.parse(schema, "Red")
      {:ok, :red}
      iex> Zoi.parse(schema, "Yellow")
      {:error, [%Zoi.Error{message: "invalid value for enum"}]}

  Integer values can also be used:
      iex> schema = Zoi.enum([1, 2, 3])
      iex> Zoi.parse(schema, 1)
      {:ok, 1}
      iex> Zoi.parse(schema, 4)
      {:error, [%Zoi.Error{message: "invalid value for enum"}]}

  And Integers with key-value pairs also is allowed:
      iex> schema = Zoi.enum([one: 1, two: 2, three: 3])
      iex> Zoi.parse(schema, 1)
      {:ok, :one}
      iex> Zoi.parse(schema, 4)
      {:error, [%Zoi.Error{message: "invalid value for enum"}]}
  """
  @doc group: "Complex Types"
  defdelegate enum(values, opts \\ []), to: Zoi.Types.Enum, as: :new

  # Refinements

  @doc """
  Validates that the string has a specific length.
  ## Example

      iex> schema = Zoi.string() |> Zoi.length(5)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "hi")
      {:error, [%Zoi.Error{message: "length must be 5"}]}
  """

  @doc group: "Refinements"
  @spec length(schema :: Zoi.Type.t(), length :: non_neg_integer()) :: Zoi.Type.t()
  def length(%Zoi.Types.String{} = schema, length) do
    schema
    |> refine({Zoi.Refinements, :refine, [[length: length], []]})
  end

  @doc """
  Validates that the input is greater than or equal to a minimum value.
  This can be used for strings, integers, floats and numbers.
  ## Example
      iex> schema = Zoi.string() |> Zoi.min(2)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "hi")
      {:error, [%Zoi.Error{message: "minimum length is 2"}]}
  """
  @doc group: "Refinements"
  @spec min(schema :: Zoi.Type.t(), min :: non_neg_integer()) :: Zoi.Type.t()
  def min(schema, min) do
    schema
    |> refine({Zoi.Refinements, :refine, [[min: min], []]})
  end

  @doc """
  Validates that the input is less than or equal to a maximum value.
  This can be used for strings, integers, floats and numbers.
  ## Example
      iex> schema = Zoi.string() |> Zoi.max(5)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "hello world")
      {:error, [%Zoi.Error{message: "maximum length is 5"}]}
  """
  @doc group: "Refinements"
  def max(schema, max) do
    schema
    |> refine({Zoi.Refinements, :refine, [[max: max], []]})
  end

  @doc """
  Validates that the input matches a given regex pattern.
  ## Example
      iex> schema = Zoi.string() |> Zoi.regex(~r/^\d+$/)
      iex> Zoi.parse(schema, "12345")
      {:ok, "12345"}
  """
  @doc group: "Refinements"
  def regex(schema, regex, opts \\ []) do
    schema
    |> refine({Zoi.Refinements, :refine, [[regex: regex], opts]})
  end

  @doc """
  Validates that the string is a valid email format.
  ## Example
      iex> schema = Zoi.string() |> Zoi.email()
      iex> Zoi.parse(schema, "test@test.com")
      {:ok, "test@test.com"}
      iex> Zoi.parse(schema, "invalid-email")
      {:error, [%Zoi.Error{message: "invalid email format"}]}
  """
  @doc group: "Refinements"
  @spec email(schema :: Zoi.Type.t()) :: Zoi.Type.t()
  def email(%Zoi.Types.String{} = schema) do
    schema
    |> regex(
      ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i,
      message: "invalid email format"
    )
  end

  @doc """
  Validates that a string starts with a specific prefix.
  ## Example

      iex> schema = Zoi.string() |> Zoi.starts_with("hello")
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.parse(schema, "world hello")
      {:error, [%Zoi.Error{message: "must start with 'hello'"}]}
  """
  @doc group: "Refinements"
  @spec starts_with(schema :: Zoi.Type.t(), prefix :: binary()) :: Zoi.Type.t()
  def starts_with(schema, prefix) do
    schema
    |> refine({Zoi.Refinements, :refine, [[starts_with: prefix], []]})
  end

  @doc """
  Validates that a string ends with a specific suffix.
  ## Example

      iex> schema = Zoi.string() |> Zoi.ends_with("world")
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.parse(schema, "hello")
      {:error, [%Zoi.Error{message: "must end with 'world'"}]}
  """
  @doc group: "Refinements"
  @spec ends_with(schema :: Zoi.Type.t(), suffix :: binary()) :: Zoi.Type.t()
  def ends_with(schema, suffix) do
    schema
    |> refine({Zoi.Refinements, :refine, [[ends_with: suffix], []]})
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
  Adds a custom validation function to the schema.
  This function will be called with the input data and options, and should return `:ok` for valid data or `{:error, reason}` for invalid data.
  ## Example

      iex> schema = Zoi.string() |> Zoi.refine(fn input, _opts ->
      ...>   if String.length(input) > 5 do
      ...>     :ok
      ...>   else
      ...>     {:error, "must be longer than 5 characters"}
      ...>   end
      ...> end)
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.parse(schema, "hi")
      {:error, [%Zoi.Error{message: "must be longer than 5 characters"}]}
  """
  @doc group: "Extensions"

  @spec refine(schema :: Zoi.Type.t(), fun :: Meta.refinement()) :: Zoi.Type.t()
  def refine(%Zoi.Types.Union{schemas: schemas} = schema, fun) do
    schemas =
      Enum.map(schemas, fn sub_schema ->
        refine(sub_schema, fun)
      end)

    %Zoi.Types.Union{schema | schemas: schemas}
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
      iex> schema = Zoi.string() |> Zoi.transform(&String.trim/1)
      iex> Zoi.parse(schema, "  hello world  ")
      {:ok, "hello world"}
  """
  @doc group: "Extensions"
  @spec transform(schema :: Zoi.Type.t(), fun :: Meta.transform()) :: Zoi.Type.t()
  def transform(%Zoi.Types.Union{schemas: schemas} = schema, fun) do
    schemas =
      Enum.map(schemas, fn sub_schema ->
        transform(sub_schema, fun)
      end)

    %Zoi.Types.Union{schema | schemas: schemas}
  end

  @spec transform(schema :: Zoi.Type.t(), fun :: function()) :: Zoi.Type.t()
  def transform(schema, fun) do
    update_in(schema.meta.transforms, fn transforms ->
      transforms ++ [fun]
    end)
  end
end
