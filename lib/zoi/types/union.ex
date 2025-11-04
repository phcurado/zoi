defmodule Zoi.Types.Union do
  @moduledoc false

  use Zoi.Type.Def, fields: [:schemas]

  def new([], _opts) do
    raise ArgumentError, "Union type must receive a list of minimum 2 schemas"
  end

  def new([_one_element], _opts) do
    raise ArgumentError, "Union type must receive a list of minimum 2 schemas"
  end

  def new(schemas, opts) when is_list(schemas) do
    apply_type(opts ++ [schemas: schemas])
  end

  def new(_schemas, _opts) do
    raise ArgumentError, "Union type must receive a list of minimum 2 schemas"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Union{schemas: schemas} = union, value, opts) do
      Enum.reduce_while(schemas, nil, fn schema, _acc ->
        ctx = Zoi.Context.new(schema, value)
        opts = Keyword.put(opts, :ctx, ctx)

        case Zoi.parse(schema, value, opts) do
          {:ok, result} ->
            {:halt, {:ok, result}}

          {:error, reason} ->
            {:cont, error(union, reason)}
        end
      end)
    end

    defp error(schema, type_error) do
      if error = schema.meta.error do
        {:error, Zoi.Error.custom_error(issue: {error, []})}
      else
        {:error, type_error}
      end
    end

    def type_spec(%Zoi.Types.Union{schemas: schemas}, opts) do
      Enum.map(schemas, &Zoi.Type.type_spec(&1, opts))
      |> Enum.reverse()
      |> Enum.reduce(&quote(do: unquote(&1) | unquote(&2)))
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
