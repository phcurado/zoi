defmodule Zoi.Types.Keyword do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :strict, :coerce, empty_values: []]

  def opts() do
    Keyword.merge(Zoi.Opts.shared_metadata(),
      strict:
        Zoi.Types.Boolean.new(
          description: "If strue, unrecognized keys will cause validation to fail."
        )
        |> Zoi.Types.Default.new(false),
      empty_values: Zoi.Opts.empty_values()
    )
    |> Zoi.Types.Keyword.new(strict: true)
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

    def type_spec(%Zoi.Types.Keyword{fields: fields}, opts) when is_list(fields) do
      case fields do
        [] ->
          quote(do: keyword())

        _ ->
          fields
          |> Enum.map(fn {key, type} ->
            quote do
              {unquote(key), unquote(Zoi.Type.type_spec(type, opts))}
            end
          end)
      end
    end

    def type_spec(%Zoi.Types.Keyword{fields: schema}, opts) when is_struct(schema) do
      quote do
        [{atom(), unquote(Zoi.Type.type_spec(schema, opts))}]
      end
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
