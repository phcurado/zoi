defmodule Zoi.Types.Map do
  @moduledoc false

  use Zoi.Type.Def, fields: [:key_type, :value_type]

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(key_type, value_type, opts) do
    apply_type(Keyword.merge(opts, key_type: key_type, value_type: value_type))
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Map{} = schema, input, _opts) when is_map(input) do
      Enum.reduce(input, {%{}, []}, fn {key, value}, {input, errors} ->
        with {:ok, key_parsed} <- Zoi.parse(schema.key_type, key),
             {:ok, value_parsed} <- Zoi.parse(schema.value_type, value) do
          {Map.put(input, key_parsed, value_parsed), errors}
        else
          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.prepend_path(&1, [key]))
            {input, Zoi.Errors.merge(errors, error)}
        end
      end)
      |> then(fn {parsed, errors} ->
        if errors == [] do
          {:ok, parsed}
        else
          {:error, errors, parsed}
        end
      end)
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:map, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Map{key_type: key_type, value_type: value_type}, opts) do
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
    def inspect(type, opts) do
      extra_fields = [
        key: Inspect.inspect(type.key_type, opts),
        value: Inspect.inspect(type.value_type, opts)
      ]

      Zoi.Inspect.build(type, opts, extra_fields)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(_schema), do: %{type: :object}
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:map/0`"
  end
end
