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
  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Union{schemas: schemas}, opts) do
      Enum.map(schemas, &Zoi.TypeSpec.spec(&1, opts))
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

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{anyOf: Enum.map(schema.schemas, &Zoi.JSONSchema.Encoder.encode/1)}
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(%{schemas: schemas}) do
      Enum.map_join(schemas, " | ", &Zoi.Describe.Encoder.encode/1)
    end
  end
end
