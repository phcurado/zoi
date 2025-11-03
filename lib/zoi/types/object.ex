defmodule Zoi.Types.Object do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :keys, :inner, :strict, :coerce]

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

    inner =
      fields
      |> Zoi.keyword(opts)
      |> Zoi.transform({__MODULE__, :__transform__, []})

    keys = Enum.map(fields, fn {key, _type} -> key end)

    opts =
      Keyword.merge([strict: false, coerce: false], opts)

    apply_type(opts ++ [fields: fields, keys: keys, inner: inner])
  end

  def new(_fields, _opts) do
    raise ArgumentError, "object must receive a map"
  end

  def __transform__(value, _opts) do
    Enum.into(value, %{})
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{inner: inner}, input, opts) when is_map(input) do
      Zoi.parse(inner, Map.to_list(input), opts)
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:object, custom_message: schema.meta.error)}
    end

    def type_spec(%Zoi.Types.Object{fields: fields}, opts) do
      fields
      |> Enum.map(fn {key, type} ->
        {key, Zoi.Type.type_spec(type, opts), type}
      end)
      |> Enum.map(fn {key, type_spec, type} ->
        case type.meta.required do
          true -> quote do: {required(unquote(key)), unquote(type_spec)}
          _ -> quote do: {optional(unquote(key)), unquote(type_spec)}
        end
      end)
      |> then(&quote(do: %{unquote_splicing(&1)}))
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
