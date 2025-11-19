defmodule Zoi.Types.Array do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner, :min_length, :max_length, :length, coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      Zoi.Types.Keyword.new(
        [
          min_length: Zoi.Types.Integer.new(description: "Minimum length of the array."),
          max_length: Zoi.Types.Integer.new(description: "Maximum length of the array."),
          length: Zoi.Types.Integer.new(description: "Exact length of the array.")
        ],
        strict: true
      )
    )
  end

  def new(inner, opts) do
    opts
    |> then(&apply_type(&1 ++ [inner: inner]))
    |> apply_option(:min_length, opts, &Zoi.Validations.Gte.set/2)
    |> apply_option(:max_length, opts, &Zoi.Validations.Lte.set/2)
    |> apply_option(:length, opts, &Zoi.Validations.Length.set/2)
  end

  defp apply_option(schema, key, opts, fun) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> fun.(schema, value)
      :error -> schema
    end
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Array{inner: inner} = schema, inputs, opts) when is_list(inputs) do
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
      |> then(&finalize_result(&1, schema, opts))
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

    defp finalize_result({parsed, errors}, schema, opts) do
      parsed = Enum.reverse(parsed)

      if errors == [] do
        case validate_constraints(schema, parsed, opts) do
          :ok ->
            {:ok, parsed}

          {:error, new_errors} ->
            {:error, new_errors, parsed}
        end
      else
        {:error, errors, parsed}
      end
    end

    defp validate_constraints(schema, parsed, opts) do
      validations = [
        fn -> Zoi.Validations.Length.validate(schema, parsed, opts) end,
        fn -> Zoi.Validations.Gte.validate(schema, parsed, opts) end,
        fn -> Zoi.Validations.Lte.validate(schema, parsed, opts) end
      ]

      errors =
        Enum.reduce(validations, [], fn validation, acc ->
          case validation.() do
            :ok -> acc
            {:error, error} -> [error | acc]
          end
        end)

      if errors == [] do
        :ok
      else
        {:error, Enum.reverse(errors)}
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

  defimpl Zoi.Validations.Gte do
    def validate(%{min_length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      if length(input) >= schema.min_length do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:array, schema.min_length, opts)}
      end
    end

    def set(schema, value) do
      %{schema | min_length: value, length: nil}
    end
  end

  defimpl Zoi.Validations.Lte do
    def validate(%{max_length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      if length(input) <= schema.max_length do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:array, schema.max_length, opts)}
      end
    end

    def set(schema, value) do
      %{schema | max_length: value, length: nil}
    end
  end

  defimpl Zoi.Validations.Length do
    def validate(%{length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      if length(input) == schema.length do
        :ok
      else
        {:error, Zoi.Error.invalid_length(:array, schema.length, opts)}
      end
    end

    def set(schema, value) do
      %{schema | length: value, min_length: nil, max_length: nil}
    end
  end
end
