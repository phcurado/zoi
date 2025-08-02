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
      Zoi.boolean()
      Zoi.number()

  Encapsulated types:

      Zoi.optional()
      Zoi.default(inner_type, default_value)

  Complex types:
      Zoi.object(fields)
      Zoi.array(element_type)
      Zoi.tuple(element_type)

  ## Coercion
  By default, `Zoi` will not attempt to infer input data to match the expected type. For example, if you define a schema that expects a string, passing an integer will result in an error.
      iex> Zoi.string() |> Zoi.parse(123)
      {:error, %Zoi.Error{message: "invalid string type"}}

  If you need coercion, you can enable it by passing the `:coerce` option:

      iex> Zoi.string(coerce: true) |> Zoi.parse(123)
      {:ok, "123"}



  """

  @type input :: any()
  @type result :: {:ok, any()} | {:error, map()}
  @type options :: keyword()

  defmodule Error do
    @type t :: %__MODULE__{
            message: binary(),
            issues: [binary()]
          }
    defexception [:message, issues: [], path: []]

    @impl true
    def exception(opts) when is_list(opts) do
      struct!(__MODULE__, opts)
    end

    def add_error(issue) when is_binary(issue) do
      %__MODULE__{issues: [issue]}
    end

    def add_error(%__MODULE__{issues: issues} = error, issue) do
      %{error | issues: [issue | issues]}
    end

    def message(%__MODULE__{issues: issues}), do: Enum.join(issues, ", ")

    defimpl Inspect do
      def inspect(error, _opts) do
        to_string(error.issues)
      end
    end
  end

  @doc """
  Parse input data against a schema.
  Accepts optional `strict: true` option to disable coercion.
  """
  @spec parse(schema :: Zoi.Type.t(), input :: input(), opts :: options) :: result()
  def parse(schema, input, opts \\ []) do
    schema
    |> Zoi.Type.parse(input, opts)
    |> case do
      {:ok, result} ->
        run_validations(schema, result)

      {:error, error} ->
        {:error, handle_error_result(error)}
    end
  end

  defp run_validations(schema, result) do
    case Zoi.Validations.run_validations(schema, result) do
      {:ok, _validated_result} ->
        {:ok, result}

      {:error, error} ->
        {:error, handle_error_result(error)}
    end
  end

  defp handle_error_result(%Zoi.Error{} = error), do: error

  defp handle_error_result(reason) when is_binary(reason) do
    Zoi.Error.add_error(reason)
  end

  # Types
  @doc """
  Defines a string type schema.

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
  defdelegate string(opts \\ []), to: Zoi.Types.String, as: :new

  @doc """
  Defines a number type schema.

  Use `Zoi.integer()` to define integer types:

      iex> shema = Zoi.integer()
      iex> Zoi.parse(shema, 42)
      {:ok, 42}

  Built-in validations for integers include:

      Zoi.min(0)
      Zoi.max(100)
  """
  defdelegate integer(opts \\ []), to: Zoi.Types.Integer, as: :new

  @doc """
  Defines a boolean type schema.

  Use `Zoi.boolean()` to define boolean types:
      iex> schema = Zoi.boolean()
      iex> Zoi.parse(schema, true)
      {:ok, true}

  For coercion, you can pass the `:coerce` option:
      iex> Zoi.boolean(coerce: true) |> Zoi.parse("true")
      {:ok, true}
  """
  defdelegate boolean(opts \\ []), to: Zoi.Types.Boolean, as: :new

  @doc """
  Makes the schema optional for the `Zoi.object/2` type.

  ## Example

      iex> schema = Zoi.object(%{name: Zoi.string()}) |> Zoi.optional()
      iex> Zoi.parse(schema, %{})
      {:ok, %{}}
  """
  defdelegate optional(opts \\ []), to: Zoi.Types.Optional, as: :new

  @doc """
  Creates a default value for the schema.
  This allows you to specify a default value that will be used if the input is `nil` or not provided.

  ## Example
      iex> schema = Zoi.string() |> Zoi.default("default value")
      iex> Zoi.parse(schema, nil)
      {:ok, "default value"}

  """
  defdelegate default(inner, value, opts \\ []), to: Zoi.Types.Default, as: :new

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
  defdelegate object(fields, opts \\ []), to: Zoi.Types.Object, as: :new

  # Validations
  @doc false
  defdelegate min(schema, min), to: Zoi.Validations.Min, as: :new

  @doc false
  defdelegate max(schema, max), to: Zoi.Validations.Max, as: :new

  @doc false
  defdelegate regex(schema, regex), to: Zoi.Validations.Regex, as: :new

  @doc false
  defdelegate email(schema, email), to: Zoi.Validations.Email, as: :new
end
