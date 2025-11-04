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
          def parse(_schema, input, _opts) when is_binary(input) do
            {:ok, input}
          end

          def parse(_schema, input, _opts) when is_boolean(input) do
            {:ok, input}
          end

          def parse(_schema, _input, _opts) do
            {:error, "invalid string or boolean type"}
          end

          def type_spec(_schema, _opts) do
            quote do
              boolean() | binary()
            end
          end
        end
      end

  You can then use this type in your schema definitions and it will handle parsing and validation as defined.
      iex> schema = StringBoolean.string_bool()
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.parse(schema, true)
      {:ok, true}
      iex> Zoi.parse(schema, 123)
      {:error,
       [
         %Zoi.Error{
           code: :custom,
           issue: {"invalid string or boolean type", []},
           message: "invalid string or boolean type",
           path: []
         }
       ]}

  In general, you will not need to implement this protocol directly. `Zoi` provides a functional API with a good set of built-in types that cover most use cases.
  For example, you can implement the `string_bool/1` function above using `Zoi.union/2` with `Zoi.string/1` and `Zoi.boolean/1` types.
      iex> schema = Zoi.union([Zoi.string(), Zoi.boolean()])
      iex> Zoi.parse(schema, "hello world")
      {:ok, "hello world"}
      iex> Zoi.parse(schema, true)

  Or use the `Zoi.string_boolean/1` function, which already covers this and more complex use cases.
  """

  def parse(schema, input, opts)

  def type_spec(schema, opts)
end
