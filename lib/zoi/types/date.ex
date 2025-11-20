defmodule Zoi.Types.Date do
  @moduledoc false
  use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      gte: Zoi.Opts.date_opts(),
      lte: Zoi.Opts.date_opts(),
      gt: Zoi.Opts.date_opts(),
      lt: Zoi.Opts.date_opts()
    )
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, %Date{} = input, opts) do
      case validate_constraints(schema, input, opts) do
        :ok -> {:ok, input}
        {:error, errors} -> {:error, errors}
      end
    end

    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      with {:ok, parsed} <- maybe_coerce(coerce, schema, input),
           :ok <- validate_constraints(schema, parsed, opts) do
        {:ok, parsed}
      end
    end

    defp maybe_coerce(true, schema, input), do: coerce(schema, input)
    defp maybe_coerce(_false, schema, _input), do: error(schema)

    defp coerce(schema, input) when is_binary(input) do
      case Date.from_iso8601(input) do
        {:error, _reason} -> error(schema)
        {:ok, parsed} -> {:ok, parsed}
      end
    end

    defp coerce(_schema, input) when is_integer(input) do
      {:ok, Date.from_gregorian_days(input)}
    end

    defp coerce(schema, _input) do
      error(schema)
    end

    defp validate_constraints(schema, input, opts) do
      errors =
        [Zoi.Validations.Gte, Zoi.Validations.Lte, Zoi.Validations.Gt, Zoi.Validations.Lt]
        |> Enum.reduce([], fn module, acc ->
          case module.validate(schema, input, opts) do
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

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:date, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: Date.t())
    end
  end

  defimpl Zoi.Validations.Gte do
    def validate(%{gte: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {min, custom_opts} = extract_date_constraint(schema.gte)
      opts = Keyword.merge(opts, custom_opts)

      case Date.compare(input, min) do
        :gt -> :ok
        :eq -> :ok
        :lt -> {:error, Zoi.Error.greater_than_or_equal_to(:date, min, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      gte = if opts[:error], do: {value, opts}, else: value
      %{schema | gte: gte}
    end

    defp extract_date_constraint({value, opts}) when is_list(opts), do: {value, opts}
    defp extract_date_constraint(value), do: {value, []}
  end

  defimpl Zoi.Validations.Lte do
    def validate(%{lte: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {max, custom_opts} = extract_date_constraint(schema.lte)
      opts = Keyword.merge(opts, custom_opts)

      case Date.compare(input, max) do
        :lt -> :ok
        :eq -> :ok
        :gt -> {:error, Zoi.Error.less_than_or_equal_to(:date, max, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      lte = if opts[:error], do: {value, opts}, else: value
      %{schema | lte: lte}
    end

    defp extract_date_constraint({value, opts}) when is_list(opts), do: {value, opts}
    defp extract_date_constraint(value), do: {value, []}
  end

  defimpl Zoi.Validations.Gt do
    def validate(%{gt: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {gt, custom_opts} = extract_date_constraint(schema.gt)
      opts = Keyword.merge(opts, custom_opts)

      case Date.compare(input, gt) do
        :gt -> :ok
        _ -> {:error, Zoi.Error.greater_than(:date, gt, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      gt = if opts[:error], do: {value, opts}, else: value
      %{schema | gt: gt}
    end

    defp extract_date_constraint({value, opts}) when is_list(opts), do: {value, opts}
    defp extract_date_constraint(value), do: {value, []}
  end

  defimpl Zoi.Validations.Lt do
    def validate(%{lt: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {lt, custom_opts} = extract_date_constraint(schema.lt)
      opts = Keyword.merge(opts, custom_opts)

      case Date.compare(input, lt) do
        :lt -> :ok
        _ -> {:error, Zoi.Error.less_than(:date, lt, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      lt = if opts[:error], do: {value, opts}, else: value
      %{schema | lt: lt}
    end

    defp extract_date_constraint({value, opts}) when is_list(opts), do: {value, opts}
    defp extract_date_constraint(value), do: {value, []}
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
