defmodule Zoi.Types.Map do
  @moduledoc false

  use Zoi.Type.Def, fields: [:key_type, :value_type, :fields, :strict, :coerce, empty_values: []]

  alias Zoi.Types.Meta

  def opts() do
    Zoi.Opts.complex_type_opts()
  end

  def new(fields, opts) when (is_map(fields) and not is_struct(fields)) or is_list(fields) do
    fields =
      Enum.map(fields, fn {key, type} ->
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
    raise ArgumentError, "expected a map with field definitions"
  end

  def new(key_type, value_type, opts) when is_struct(key_type) do
    opts =
      Keyword.merge(
        [strict: false, coerce: false],
        opts
      )

    apply_type(Keyword.merge(opts, key_type: key_type, value_type: value_type))
  end

  def new(_key_value, _value_type, _opts) do
    raise ArgumentError, "expected a map with valid key and type definitions"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Map{fields: fields} = type, input, opts)
        when is_list(fields) and is_map(input) and not is_struct(input) do
      Zoi.Types.KeyValue.parse(type, input, opts)
    end

    def parse(%Zoi.Types.Map{} = schema, input, _opts)
        when is_map(input) and not is_struct(input) do
      Enum.reduce(input, {%{}, []}, fn {key, value}, {input, errors} ->
        with {:ok, key_parsed} <- Zoi.parse(schema.key_type, key),
             {:ok, value_parsed} <- Zoi.parse(schema.value_type, value) do
          {Map.put(input, key_parsed, value_parsed), errors}
        else
          {:error, err} ->
            new_errors =
              Enum.reduce(err, errors, fn e, acc ->
                [Zoi.Error.prepend_path(e, [key]) | acc]
              end)

            {input, new_errors}
        end
      end)
      |> then(fn {parsed, errors} ->
        if errors == [] do
          {:ok, parsed}
        else
          {:error, Enum.reverse(errors), parsed}
        end
      end)
    end

    def parse(%Zoi.Types.Map{fields: fields, coerce: true} = type, input, opts)
        when is_list(fields) and is_struct(input) do
      parse(type, Map.from_struct(input), opts)
    end

    def parse(%Zoi.Types.Map{coerce: true} = schema, input, opts)
        when is_struct(input) do
      parse(schema, Map.from_struct(input), opts)
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:map, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    # If the keys are strings, there isn't a good way to represent that in typespecs
    def spec(%Zoi.Types.Map{fields: [{key, _val} | _rest]}, _opts) when is_binary(key) do
      quote do: map()
    end

    def spec(%Zoi.Types.Map{fields: fields}, opts) when is_list(fields) do
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

    def spec(%Zoi.Types.Map{key_type: key_type, value_type: value_type}, opts)
        when is_struct(key_type) do
      key_spec = Zoi.TypeSpec.spec(key_type, opts)
      value_spec = Zoi.TypeSpec.spec(value_type, opts)

      # If key and value are any type, we use map() (any map)
      if key_type == Zoi.any() and value_type == Zoi.any() do
        quote do
          map()
        end
      else
        quote do
          %{optional(unquote(key_spec)) => unquote(value_spec)}
        end
      end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Zoi.Types.Map{fields: fields} = type, opts) when is_list(fields) do
      fields_doc =
        container_doc("%{", fields, "}", %Inspect.Opts{limit: 10}, fn
          {key, schema}, _opts -> concat("#{key}: ", Inspect.inspect(schema, opts))
        end)

      Zoi.Inspect.build(type, opts, fields: fields_doc)
    end

    # Key/value mode - simple format without coerce/strict
    def inspect(type, opts) do
      list = [
        key: Inspect.inspect(type.key_type, opts),
        value: Inspect.inspect(type.value_type, opts)
      ]

      container_doc("#Zoi.map<", list, ">", %Inspect.Opts{limit: 8}, fn
        {key, value}, _opts -> concat("#{key}: ", value)
      end)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(%Zoi.Types.Map{fields: fields} = schema) when is_list(fields) do
      %{
        type: :object,
        properties:
          Enum.into(fields, %{}, fn {key, value} ->
            {key, Zoi.JSONSchema.encode_schema(value)}
          end),
        required:
          Enum.flat_map(fields, fn {k, v} ->
            if Meta.required?(v.meta), do: [k], else: []
          end),
        additionalProperties: not schema.strict
      }
    end

    def encode(_schema), do: %{type: :object}
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:map/0`"
  end
end
