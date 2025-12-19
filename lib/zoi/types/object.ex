defmodule Zoi.Types.Object do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :strict, :coerce, empty_values: []]

  alias Zoi.Types.Meta

  def opts() do
    Zoi.Opts.complex_type_opts()
  end

  def new(fields, opts) when is_map(fields) or is_list(fields) do
    fields =
      fields
      |> Enum.map(fn {key, type} ->
        if type.meta.required == nil do
          {key, Zoi.required(type)}
        else
          {key, type}
        end
      end)

    opts =
      Keyword.merge(
        [strict: false, coerce: false],
        opts
      )

    apply_type(opts ++ [fields: fields])
  end

  def new(_fields, _opts) do
    raise ArgumentError, "object must receive a map"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{} = obj, input, opts) when is_map(input) do
      Zoi.Types.KeyValue.parse(obj, input, opts)
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:object, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    alias Zoi.Types.Meta

    def spec(%Zoi.Types.Object{fields: [{key, _val} | _rest]}, _opts) when is_binary(key) do
      # If the keys are strings, there isn't a good way to represent that in typespecs
      quote do: map()
    end

    def spec(%Zoi.Types.Object{fields: fields}, opts) do
      fields
      |> Enum.map(fn {key, type} ->
        {key, Zoi.TypeSpec.spec(type, opts), type}
      end)
      |> Enum.map(fn {key, type_spec, type} ->
        case Meta.required?(type.meta) do
          true -> quote do: {required(unquote(key)), unquote(type_spec)}
          _ -> quote do: {optional(unquote(key)), unquote(type_spec)}
        end
      end)
      |> then(&quote(do: %{unquote_splicing(&1)}))
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(type, opts) do
      fields_doc =
        container_doc("%{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
          {key, schema}, _opts -> concat("#{key}: ", Inspect.inspect(schema, opts))
        end)

      Zoi.Inspect.build(type, opts, fields: fields_doc)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{
        type: :object,
        properties:
          Enum.into(schema.fields, %{}, fn {key, value} ->
            {key, Zoi.JSONSchema.Encoder.encode(value)}
          end),
        required:
          Enum.flat_map(schema.fields, fn {k, v} ->
            if Meta.required?(v.meta), do: [k], else: []
          end),
        additionalProperties: not schema.strict
      }
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:map/0`"
  end
end
