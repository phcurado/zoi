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

  alias Zoi.Types.Meta

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
  Accepts optional `coerce: true` option to enable coercion.
  """
  @spec parse(schema :: Zoi.Type.t(), input :: input(), opts :: options) :: result()
  def parse(schema, input, opts \\ []) do
    with {:ok, result} <- Zoi.Type.parse(schema, input, opts),
         {:ok, _validated_result} <- Meta.run_validations(schema, result),
         {:ok, result} <- Meta.run_transforms(schema, result) do
      {:ok, result}
    else
      {:error, %Zoi.Error{} = error} -> {:error, error}
      {:error, reason} when is_binary(reason) -> {:error, Zoi.Error.add_error(reason)}
    end
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

  @doc """
  Validates that the string has a specific length.
  ## Example

      iex> schema = Zoi.string() |> Zoi.length(5)
      iex> Zoi.parse(schema, "hello")
      {:ok, "hello"}
      iex> Zoi.parse(schema, "hi")
      {:error, %Zoi.Error{issues: ["length must be 5"]}}
  """
  @spec length(schema :: Zoi.Type.t(), length :: non_neg_integer()) :: Zoi.Type.t()
  def length(%Zoi.Types.String{} = schema, length) do
    schema
    |> refine(fn input, _opts ->
      if String.length(input) == length do
        :ok
      else
        {:error, "length must be #{length}"}
      end
    end)
  end

  @doc false
  def min(%Zoi.Types.String{} = schema, min) do
    schema
    |> refine(fn input, _opts ->
      if String.length(input) >= min do
        :ok
      else
        {:error, "minimum length is #{min}"}
      end
    end)
  end

  def min(%Zoi.Types.Integer{} = schema, min) do
    schema
    |> refine(fn input, _opts ->
      if input >= min do
        :ok
      else
        {:error, "minimum value is #{min}"}
      end
    end)
  end

  @doc false
  def max(%Zoi.Types.String{} = schema, max) do
    schema
    |> refine(fn input, _opts ->
      if String.length(input) <= max do
        :ok
      else
        {:error, "maximum length is #{max}"}
      end
    end)
  end

  def max(%Zoi.Types.Integer{} = schema, max) do
    schema
    |> refine(fn input, _opts ->
      if input <= max do
        :ok
      else
        {:error, "maximum value is #{max}"}
      end
    end)
  end

  @doc false
  def regex(%Zoi.Types.String{} = schema, regex, opts \\ []) do
    message = Keyword.get(opts, :message, "regex does not match")

    schema
    |> refine(fn input, _opts ->
      if String.match?(input, regex) do
        :ok
      else
        {:error, message}
      end
    end)
  end

  @doc """
  Validates that the string is a valid email format.
  ## Example
      iex> schema = Zoi.string() |> Zoi.email()
      iex> Zoi.parse(schema, "test@test.com")
      {:ok, "test@test.com"}
      iex> Zoi.parse(schema, "invalid-email")
      {:error, %Zoi.Error{issues: ["invalid email format"]}}
  """
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
      {:error, %Zoi.Error{issues: ["must start with 'hello'"]}}

  """
  @spec starts_with(schema :: Zoi.Type.t(), prefix :: binary()) :: Zoi.Type.t()
  def starts_with(schema, prefix) do
    schema
    |> refine(fn input, _opts ->
      if String.starts_with?(input, prefix) do
        :ok
      else
        {:error, "must start with '#{prefix}'"}
      end
    end)
  end

  # Transforms

  @doc """
  Trims whitespace from the beginning and end of a string.
  ## Example

      iex> schema = Zoi.string() |> Zoi.trim()
      iex> Zoi.parse(schema, "  hello world  ")
      {:ok, "hello world"}
  """
  @spec trim(schema :: Zoi.Type.t()) :: Zoi.Type.t()
  def trim(%Zoi.Types.String{} = schema) do
    transform(schema, &String.trim/1)
  end

  @doc """
  Converts a string to lowercase.
  ## Example
      iex> schema = Zoi.string() |> Zoi.to_downcase()
      iex> Zoi.parse(schema, "Hello World")
      {:ok, "hello world"}
  """
  @spec to_downcase(schema :: Zoi.Type.t()) :: Zoi.Type.t()
  def to_downcase(%Zoi.Types.String{} = schema) do
    transform(schema, &String.downcase/1)
  end

  @doc """
  Converts a string to uppercase.
  ## Example
      iex> schema = Zoi.string() |> Zoi.to_upcase()
      iex> Zoi.parse(schema, "Hello World")
      {:ok, "HELLO WORLD"}
  """
  @spec to_upcase(schema :: Zoi.Type.t()) :: Zoi.Type.t()
  def to_upcase(%Zoi.Types.String{} = schema) do
    transform(schema, &String.upcase/1)
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
      {:error, %Zoi.Error{issues: ["must be longer than 5 characters"]}}
  """
  @spec refine(schema :: Zoi.Type.t(), fun :: function()) :: Zoi.Type.t()
  def refine(schema, fun, opts \\ []) do
    update_in(schema.meta.validations, fn transforms ->
      transforms ++ [{:refine, fun, opts}]
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
  @spec transform(schema :: Zoi.Type.t(), fun :: function()) :: Zoi.Type.t()
  def transform(schema, fun) do
    update_in(schema.meta.transforms, fn transforms ->
      transforms ++ [fun]
    end)
  end
end
