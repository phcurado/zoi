defmodule Zoi.Types.Intersection do
  @moduledoc false

  use Zoi.Type.Def, fields: [:schemas]

  def new([], _opts) do
    raise ArgumentError, "Intersection type must be receive a list of minimum 2 schemas"
  end

  def new([_one_element], _opts) do
    raise ArgumentError, "Intersection type must be receive a list of minimum 2 schemas"
  end

  def new(schemas, opts) when is_list(schemas) do
    apply_type(opts ++ [schemas: schemas])
  end

  def new(_schemas, _opts) do
    raise ArgumentError, "Intersection type must be receive a list of minimum 2 schemas"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Intersection{schemas: schemas} = intersection, value, opts) do
      Enum.reduce_while(schemas, nil, fn schema, _acc ->
        ctx = Zoi.Context.new(schema, value)
        opts = Keyword.put(opts, :ctx, ctx)

        case Zoi.parse(schema, value, opts) do
          {:ok, result} ->
            {:cont, {:ok, result}}

          {:error, reason} ->
            {:halt, error(intersection, reason)}
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

    # There is no direct representation of a intersection in Elixir types, so we use union `|`
    def type_spec(%Zoi.Types.Intersection{schemas: schemas}, opts) do
      Enum.map(schemas, &Zoi.type_spec(&1, opts))
      |> Enum.reverse()
      |> Enum.reduce(&quote(do: unquote(&1) | unquote(&2)))
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      schemas_doc =
        container_doc("[", type.schemas, "]", %Inspect.Opts{limit: 5}, fn
          schema, _opts -> Inspect.inspect(schema, opts)
        end)

      Zoi.Inspect.build(type, opts, schemas: schemas_doc)
    end
  end
end
