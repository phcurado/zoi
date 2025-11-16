defmodule Zoi.Types.Tuple do
  @moduledoc false
  use Zoi.Type.Def, fields: [:fields, :length]

  def opts() do
    Zoi.Types.Keyword.new(
      [
        description: Zoi.Opts.description(),
        example: Zoi.Opts.example(),
        metadata: Zoi.Opts.metadata(),
        error: Zoi.Opts.error()
      ],
      []
    )
  end

  def new(fields, opts) when is_tuple(fields) do
    fields = Tuple.to_list(fields)
    apply_type(Keyword.merge(opts, fields: fields, length: length(fields)))
  end

  def new(_fields, _opts) do
    raise ArgumentError, "must be a tuple"
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) when is_tuple(input) do
      input = Tuple.to_list(input)
      input_length = length(input)

      if input_length != schema.length do
        {:error, Zoi.Error.invalid_tuple(schema.length, input_length, error: schema.meta.error)}
      else
        parse_fields(schema, input, opts)
      end
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:tuple, error: schema.meta.error)}
    end

    defp parse_fields(schema, input, opts) do
      schema.fields
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {field, index}, {parsed, errors} ->
        case Zoi.parse(field, Enum.at(input, index), opts) do
          {:ok, value} ->
            {[value | parsed], errors}

          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.prepend_path(&1, [index]))
            {parsed, Zoi.Errors.merge(errors, error)}
        end
      end)
      |> then(fn {parsed, errors} ->
        parsed_tuple =
          parsed
          |> Enum.reverse()
          |> List.to_tuple()

        if errors == [] do
          {:ok, parsed_tuple}
        else
          {:error, errors, parsed_tuple}
        end
      end)
    end

    def type_spec(%Zoi.Types.Tuple{fields: fields}, opts) do
      field_specs = Enum.map(fields, &Zoi.Type.type_spec(&1, opts))

      {:{}, [], field_specs}
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
