defmodule Zoi.Types.ExclusiveUnion do
  @moduledoc false

  use Zoi.Type.Def, fields: [:schemas]

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(schemas, opts) when is_list(schemas) and length(schemas) >= 2 do
    apply_type(opts ++ [schemas: schemas])
  end

  def new(_schemas, _opts) do
    raise ArgumentError, "Exclusive union type must receive a list of minimum 2 schemas"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.ExclusiveUnion{schemas: schemas} = union, value, opts) do
      results = Enum.map(schemas, &parse_schema(&1, value, opts))

      case Enum.filter(results, & &1.valid?) do
        [ctx] ->
          {:ok, ctx.parsed}

        [] ->
          error(union, List.last(results).errors)

        _ ->
          error(
            union,
            Zoi.Error.custom_error(issue: {"input matches more than one union schema", []})
          )
      end
    end

    defp parse_schema(schema, value, opts) do
      ctx = Zoi.Context.new(schema, value)
      Zoi.Context.parse(ctx, Keyword.put(opts, :ctx, ctx))
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
    def spec(%Zoi.Types.ExclusiveUnion{schemas: schemas}, opts) do
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

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{oneOf: Enum.map(schema.schemas, &Zoi.JSONSchema.encode_schema/1)}
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(%{schemas: schemas}) do
      Enum.map_join(schemas, " | ", &Zoi.Describe.Encoder.encode/1)
    end
  end
end
