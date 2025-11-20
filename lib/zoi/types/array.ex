defmodule Zoi.Types.Array do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner, :min_length, :max_length, :length, coerce: false]

  def opts() do
    constraint = Zoi.Opts.constraint_schema()

    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      Zoi.Types.Keyword.new(
        [
          min_length: constraint,
          max_length: constraint,
          length: constraint
        ],
        strict: true
      )
    )
  end

  def new(inner, opts) when is_struct(inner) do
    schema = apply_type([inner: inner] ++ opts)

    # Ensure length overrides min/max when both are present
    if Keyword.has_key?(opts, :length) do
      Zoi.Validations.Length.set(schema, opts[:length])
    else
      schema
    end
  end

  def new(inner, _opts) do
    raise ArgumentError,
          "you should use a valid Zoi schema, got: #{inspect(inner)}"
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
      {min, custom_opts} = Zoi.Opts.extract_constraint(schema.min_length)
      opts = Keyword.merge(opts, custom_opts)

      if length(input) >= min do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:array, min, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      min_length = if opts[:error], do: {value, opts}, else: value
      %{schema | min_length: min_length, length: nil}
    end
  end

  defimpl Zoi.Validations.Lte do
    def validate(%{max_length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {max, custom_opts} = Zoi.Opts.extract_constraint(schema.max_length)
      opts = Keyword.merge(opts, custom_opts)

      if length(input) <= max do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:array, max, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      max_length = if opts[:error], do: {value, opts}, else: value
      %{schema | max_length: max_length, length: nil}
    end
  end

  defimpl Zoi.Validations.Length do
    def validate(%{length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {len, custom_opts} = Zoi.Opts.extract_constraint(schema.length)
      opts = Keyword.merge(opts, custom_opts)

      if length(input) == len do
        :ok
      else
        {:error, Zoi.Error.invalid_length(:array, len, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      length = if opts[:error], do: {value, opts}, else: value
      %{schema | length: length, min_length: nil, max_length: nil}
    end
  end
end
