defmodule Zoi.Types.Union do
  @moduledoc false

  use Zoi.Type.Def, fields: [:schemas]

  def new([], _opts) do
    raise ArgumentError, "Union type must be receive a list of minimum 2 schemas"
  end

  def new([_one_element], _opts) do
    raise ArgumentError, "Union type must be receive a list of minimum 2 schemas"
  end

  def new(schemas, opts) when is_list(schemas) do
    apply_type(opts ++ [schemas: schemas])
  end

  def new(_schemas, _opts) do
    raise ArgumentError, "Union type must be receive a list of minimum 2 schemas"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Union{schemas: schemas}, value, opts) do
      Enum.reduce_while(schemas, nil, fn schema, _acc ->
        case Zoi.parse(schema, value, opts) do
          {:ok, result} ->
            {:halt, {:ok, result}}

          {:error, reason} ->
            {:cont, {:error, reason}}
        end
      end)
    end
  end
end
