defmodule Zoi.Types.Keyword do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :strict, :coerce, empty_values: []]

  def opts() do
    Zoi.Opts.complex_type_opts()
  end

  def new(fields, opts) when is_list(fields) or is_struct(fields) do
    opts =
      Keyword.merge(
        [strict: false, coerce: false],
        opts
      )

    apply_type(opts ++ [fields: fields])
  end

  def new(_fields, _opts) do
    raise ArgumentError, "keyword must receive a keyword list"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Keyword{fields: fields} = type, input, opts)
        when is_list(fields) and is_list(input) do
      Zoi.Types.KeyValue.parse(type, input, opts)
    end

    def parse(%Zoi.Types.Keyword{fields: value_schema, empty_values: empty_values}, input, opts)
        when is_list(input) and is_struct(value_schema) do
      {parsed, errors} =
        Enum.reduce(input, {[], []}, fn {key, raw_value}, {acc, errs} ->
          if raw_value in empty_values do
            {acc, errs}
          else
            ctx =
              Zoi.Context.new(value_schema, raw_value)
              |> Zoi.Context.add_path([key])

            ctx = Zoi.Context.parse(ctx, opts)

            if ctx.valid? do
              {[{key, ctx.parsed} | acc], errs}
            else
              patched = Enum.map(ctx.errors, &Zoi.Error.prepend_path(&1, [key]))
              {acc, Zoi.Errors.merge(errs, patched)}
            end
          end
        end)

      parsed = Enum.reverse(parsed)

      if errors == [] do
        {:ok, parsed}
      else
        {:error, errors, parsed}
      end
    end

    def parse(schema, _, _) do
      {:error,
       Zoi.Error.invalid_type(:keyword,
         issue: "invalid type: expected keyword list",
         error: schema.meta.error
       )}
    end

  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Keyword{fields: fields}, opts) when is_list(fields) do
      case fields do
        [] ->
          quote(do: keyword())

        _ ->
          fields
          |> Enum.map(fn {key, type} ->
            quote do
              {unquote(key), unquote(Zoi.TypeSpec.spec(type, opts))}
            end
          end)
      end
    end

    def spec(%Zoi.Types.Keyword{fields: schema}, opts) when is_struct(schema) do
      quote do
        [{atom(), unquote(Zoi.TypeSpec.spec(schema, opts))}]
      end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      fields_doc =
        case type.fields do
          fields when is_list(fields) ->
            container_doc("[", fields, "]", %Inspect.Opts{limit: 10}, fn
              {key, schema}, _opts -> concat("#{key}: ", Inspect.inspect(schema, opts))
            end)

          schema_type ->
            Inspect.inspect(schema_type, opts)
        end

      Zoi.Inspect.build(type, opts, fields: fields_doc)
    end
  end
end
