defmodule Zoi.Types.Tuple do
  @moduledoc false
  use Zoi.Type.Def, fields: [:fields, :length]

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

      if length(input) != schema.length do
        error(schema)
      else
        parse_fields(schema, input, opts)
      end
    end

    def parse(schema, _, _) do
      error(schema)
    end

    defp parse_fields(schema, input, opts) do
      schema.fields
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {field, index}, {parsed, errors} ->
        case Zoi.parse(field, Enum.at(input, index), opts) do
          {:ok, value} ->
            {[value | parsed], errors}

          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.add_path(&1, [index]))
            {parsed, Zoi.Errors.merge(errors, error)}
        end
      end)
      |> then(fn {parsed, errors} ->
        if errors == [] do
          {:ok,
           parsed
           |> Enum.reverse()
           |> List.to_tuple()}
        else
          {:error, errors}
        end
      end)
    end

    defp error(schema) do
      {:error,
       schema.meta.error || "invalid type: must be a tuple with #{schema.length} elements"}
    end

    def type_spec(%Zoi.Types.Tuple{fields: fields}, opts) do
      field_specs = Enum.map(fields, &Zoi.Type.type_spec(&1, opts))

      {:tuple, [], field_specs}
    end
  end
end
