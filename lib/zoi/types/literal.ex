defmodule Zoi.Types.Literal do
  @moduledoc false

  use Zoi.Type.Def, fields: [:value]

  def new(value, opts) do
    apply_type(opts ++ [value: value])
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Literal{value: value} = schema, input, _opts) do
      if input === value do
        {:ok, input}
      else
        {:error, Zoi.Error.invalid_literal(value, error: schema.meta.error)}
      end
    end

    def type_spec(%Zoi.Types.Literal{value: value}, _opts) do
      case value do
        nil -> quote(do: nil)
        true -> quote(do: true)
        false -> quote(do: false)
        _ when is_map(value) -> quote(do: map())
        _ when is_list(value) -> quote(do: list())
        value -> quote(do: unquote(value))
      end
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
