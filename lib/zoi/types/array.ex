defmodule Zoi.Types.Array do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner, :coerce]

  def new(inner, opts) do
    opts = Keyword.merge([coerce: false], opts)
    apply_type(opts ++ [inner: inner])
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Array{inner: inner}, inputs, _opts) when is_list(inputs) do
      inputs
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {input, index}, {parsed, errors} ->
        ctx = Zoi.Context.new(inner, input) |> Zoi.Context.add_path([index])

        case Zoi.parse(inner, input, ctx: ctx) do
          {:ok, value} ->
            {[value | parsed], errors}

          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.prepend_path(&1, [index]))
            {parsed, Zoi.Errors.merge(errors, error)}
        end
      end)
      |> then(fn {parsed, errors} ->
        parsed = Enum.reverse(parsed)

        if errors == [] do
          {:ok, parsed}
        else
          {:error, errors, parsed}
        end
      end)
    end

    def parse(%Zoi.Types.Array{coerce: true} = schema, inputs, opts) when is_map(inputs) do
      cond do
        has_index_keys?(inputs) ->
          inputs
          |> Enum.filter(fn {key, _value} -> index_key?(key) end)
          |> Enum.sort_by(fn {key, _value} -> parse_index(key) end)
          |> Enum.map(fn {_key, value} -> value end)
          |> then(&parse(schema, &1, opts))

        map_size(inputs) == 0 ->
          parse(schema, [], opts)

        true ->
          parse(schema, [inputs], opts)
      end
    end

    def parse(%Zoi.Types.Array{} = schema, input, opts) when is_tuple(input) do
      input
      |> Tuple.to_list()
      |> then(fn list -> parse(schema, list, opts) end)
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:array, error: schema.meta.error)}
    end

    def type_spec(%Zoi.Types.Array{inner: inner}, opts) do
      inner_spec = Zoi.Type.type_spec(inner, opts)

      quote do
        [unquote(inner_spec)]
      end
    end

    defp has_index_keys?(map) do
      Enum.any?(map, fn {key, _value} -> index_key?(key) end)
    end

    defp index_key?(key) when is_integer(key), do: true

    defp index_key?(key) when is_binary(key) do
      case Integer.parse(key) do
        {_int, ""} -> true
        _ -> false
      end
    end

    defp index_key?(_), do: false

    defp parse_index(key) when is_integer(key), do: key

    defp parse_index(key) when is_binary(key) do
      {int, _} = Integer.parse(key)
      int
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
