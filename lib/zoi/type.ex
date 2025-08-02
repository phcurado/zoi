defprotocol Zoi.Type do
  @moduledoc """
  Protocol for defining types in Zoi.

  Types are used to validate and parse data according to a defined schema.
  You can implement this protocol for custom types to handle specific validation and parsing logic.

  ## Example
  To create a custom type, you can define a module and implement the `Zoi.Type` protocol:
      defmodule StringBoolean do
        use Zoi.Type

        # `apply_type/1` is a helper function that will create the struct with the given options.
        def string_bool(opts \\ []) do
          apply_type(opts)
        end

        defimpl Zoi.Type do
          # This function is called to parse the input according to the schema.
          def parse(schema, input, opts) when is_binary(input) do
            {:ok, input}
          end

          def parse(schema, input, opts) when is_boolean(input) do
            {:ok, input}
          end

          def parse(_schema, _input, _opts) do
            {:error, "invalid string or boolean type"}
          end
        end
      end

  You can then use this type in your schema definitions and it will handle parsing and validation as defined.
      iex> schema = StringBoolean.string_bool()
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.Type.parse(schema, true)
      {:ok, true}
      iex> Zoi.Type.parse(schema, 123)
      {:error, %Zoi.Error{message: "invalid string or boolean type"}}

  ## Custom validation
  You can also implement custom validation logic from the built-in validations. 
  For example, if you want to validate a string against a regex pattern, you can do so by implementing the `Zoi.Validations.Regex` protocol:

      defimpl Zoi.Validations.Regex, for: StringBoolean do
        def validate(schema, input, regex) do
          if String.match?(input, regex) do
            :ok
          else
            {:error, "regex does not match"}
          end
        end
      end
  """

  @doc """
  Parses the `value` according to the `schema`. Responsible for coercion and missing values.

  Accepts an optional `opts` keyword list for additional options like `coercion: true` to enable input coercion.
  If `coercion` is set to `false`, it will not attempt to coerce the input and will only validate the type.

  ## Examples
  To parse a string input:

      iex> schema = Zoi.string()
      iex> Zoi.Type.parse(schema, "hello world")
      {:ok, "hello world"}

  Since `Zoi.string/1` creates the an internal struct and implements the `Zoi.Type` protocol,
  it can handle the parsing logic defined in their internal module.
  """

  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])

    quote do
      defstruct unquote(fields) ++ [meta: nil]

      def apply_type(opts \\ []) do
        {meta, opts} = Zoi.Types.Meta.create_meta(opts)
        opts = Keyword.merge(opts, meta: meta)
        struct!(__MODULE__, opts)
      end
    end
  end

  def parse(schema, input, opts)
end
