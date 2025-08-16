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
            {:halt, {:error, intersection.meta.error || reason}}
        end
      end)
    end
  end
end
