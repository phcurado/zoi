defmodule Zoi.Types.Tuple do
  @moduledoc false
  use Zoi.Type.Def, fields: [:fields, :length]

  def opts() do
    Zoi.Opts.meta_opts()
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
  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Tuple{fields: fields}, opts) do
      field_specs = Enum.map(fields, &Zoi.TypeSpec.spec(&1, opts))

      {:{}, [], field_specs}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      fields_doc =
        container_doc("{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
          field, _opts -> Inspect.inspect(field, opts)
        end)

      Zoi.Inspect.build(type, opts, fields: fields_doc)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{
        type: :array,
        prefixItems: Enum.map(schema.fields, &Zoi.JSONSchema.Encoder.encode/1)
      }
    end
  end
end
