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
    Zoi.Type.parse(schema, input, opts)
  end

  # Types
  defdelegate string(opts \\ []), to: Zoi.Types.String, as: :new
  defdelegate integer(opts \\ []), to: Zoi.Types.Integer, as: :new
  defdelegate boolean(opts \\ []), to: Zoi.Types.Boolean, as: :new
  defdelegate optional(opts \\ []), to: Zoi.Types.Optional, as: :new
  defdelegate default(inner, value, opts \\ []), to: Zoi.Types.Default, as: :new
  defdelegate object(fields, opts \\ []), to: Zoi.Types.Object, as: :new

  # Validations
  defdelegate min(schema, min), to: Zoi.Validations.Min, as: :new
  defdelegate max(schema, max), to: Zoi.Validations.Max, as: :new
  defdelegate regex(schema, regex), to: Zoi.Validations.Regex, as: :new
  defdelegate email(schema, email), to: Zoi.Validations.Email, as: :new
end
