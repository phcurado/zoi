defprotocol Zoi.Type do
  @moduledoc ~S"""
  Protocol for defining types in Zoi.

  Types are used to validate and parse data according to a defined schema.
  You can implement this protocol for custom types to handle specific validation and parsing logic.

  ## Example
  To create a custom type, you can define a module and implement the `Zoi.Type` protocol:
      defmodule StringBoolean do
        use Zoi.Type.Def

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
  """

  def parse(schema, input, opts)

  def type_spec(schema, opts)
end
