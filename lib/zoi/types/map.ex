defmodule Zoi.Types.Map do
  @moduledoc false

  use Zoi.Type.Def, fields: [:key_type, :value_type]

  def new(key_type, value_type, opts) do
    opts = Keyword.merge([error: "invalid type: must be a map"], opts)
    apply_type(Keyword.merge(opts, key_type: key_type, value_type: value_type))
  end

  def new(opts) do
    new(Zoi.any(), Zoi.any(), opts)
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Map{} = schema, input, _opts) when is_map(input) do
      Enum.reduce(input, {%{}, []}, fn {key, value}, {input, errors} ->
        with {:ok, key_parsed} <- Zoi.parse(schema.key_type, key),
             {:ok, value_parsed} <- Zoi.parse(schema.value_type, value) do
          {Map.put(input, key_parsed, value_parsed), errors}
        else
          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.add_path(&1, [key]))
            {input, Zoi.Errors.merge(errors, error)}
        end
      end)
      |> then(fn {parsed, errors} ->
        if errors == [] do
          {:ok, parsed}
        else
          {:error, errors}
        end
      end)
    end

    def parse(schema, _, _) do
      {:error, schema.meta.error}
    end

    def type_spec(%Zoi.Types.Map{key_type: key_type, value_type: value_type}, opts) do
      key_spec = Zoi.Type.type_spec(key_type, opts)
      value_spec = Zoi.Type.type_spec(value_type, opts)

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
      opts =
        Map.put(
          opts,
          :extra_fields,
          key: Zoi.Inspect.inspect_type(type.key_type, opts),
          value: Zoi.Inspect.inspect_type(type.value_type, opts)
        )

      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
