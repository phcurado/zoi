defprotocol Zoi.TypeSpec do
  @moduledoc """
  Protocol for generating Elixir type specifications from Zoi schemas.

  Each type can implement this protocol to define how it should be represented
  as an Elixir typespec. This is used by `Zoi.type_spec/1` to generate type
  specifications that can be used with `@type` attributes.

  ## Example

      defmodule MyCustomType do
        use Zoi.Type.Def

        defimpl Zoi.TypeSpec do
          def spec(_schema, _opts) do
            quote(do: my_custom_type())
          end
        end
      end
  """

  @fallback_to_any true

  @doc """
  Returns a quoted Elixir type specification for the given schema.
  """
  @spec spec(Zoi.schema(), Zoi.options()) :: Macro.t()
  def spec(schema, opts)
end

defimpl Zoi.TypeSpec, for: Any do
  def spec(schema, _opts) do
    raise ArgumentError, "TypeSpec not implemented for schema: #{inspect(schema)}"
  end
end
