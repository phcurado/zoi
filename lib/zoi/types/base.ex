defmodule Zoi.Types.Base do
  @moduledoc """
  Base module for Zoi types. It adds common functionality for defining types in Zoi.
  You can pass the `fields` option to define the fields of the struct for your type.
  Every type in `Zoi` is a struct that includes some default fields. The type module should implement the `new/1` function to create a new instance of the type.
  You can then implement the `Zoi.Type` protocol for your type to define how it should parse and validate input. Check the `Zoi.Types.String` module for an example
  of how to use this base module.
  """

  @callback new(opts :: keyword()) :: struct()

  defmacro __using__(opts \\ []) do
    struct_fields = opts[:fields] || []

    quote do
      @behaviour Zoi.Types.Base
      defstruct unquote(struct_fields) ++ [validations: []]

      def new(opts \\ []) do
        struct!(__MODULE__, opts)
      end

      defoverridable Zoi.Types.Base
    end
  end
end
