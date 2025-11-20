defmodule Zoi.Types.Float do
  @moduledoc false

  use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, coerce: false]

  def opts() do
    constraint = Zoi.Opts.constraint_schema()

    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      Zoi.Types.Keyword.new(
        [
          gte: constraint,
          lte: constraint,
          gt: constraint,
          lt: constraint
        ],
        strict: true
      )
    )
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      with {:ok, parsed} <- parse_type(input, coerce, schema),
           :ok <- validate_constraints(schema, parsed, opts) do
        {:ok, parsed}
      end
    end

    defp parse_type(input, _coerce, _schema) when is_float(input), do: {:ok, input}

    defp parse_type(input, true, schema) when is_binary(input) do
      case Float.parse(input) do
        {float, ""} -> {:ok, float}
        _error -> error(schema)
      end
    end

    defp parse_type(_input, _coerce, schema), do: error(schema)

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
      {:error, Zoi.Error.invalid_type(:float, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: float())
    end
  end

  defimpl Zoi.Validations.Gte do
    def validate(%{gte: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {min, custom_opts} = Zoi.Opts.extract_constraint(schema.gte)
      opts = Keyword.merge(opts, custom_opts)

      if input >= min do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:number, min, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      gte = if opts[:error], do: {value, opts}, else: value
      %{schema | gte: gte}
    end
  end

  defimpl Zoi.Validations.Lte do
    def validate(%{lte: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {max, custom_opts} = Zoi.Opts.extract_constraint(schema.lte)
      opts = Keyword.merge(opts, custom_opts)

      if input <= max do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:number, max, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      lte = if opts[:error], do: {value, opts}, else: value
      %{schema | lte: lte}
    end
  end

  defimpl Zoi.Validations.Gt do
    def validate(%{gt: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {gt, custom_opts} = Zoi.Opts.extract_constraint(schema.gt)
      opts = Keyword.merge(opts, custom_opts)

      if input > gt do
        :ok
      else
        {:error, Zoi.Error.greater_than(:number, gt, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      gt = if opts[:error], do: {value, opts}, else: value
      %{schema | gt: gt}
    end
  end

  defimpl Zoi.Validations.Lt do
    def validate(%{lt: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      {lt, custom_opts} = Zoi.Opts.extract_constraint(schema.lt)
      opts = Keyword.merge(opts, custom_opts)

      if input < lt do
        :ok
      else
        {:error, Zoi.Error.less_than(:number, lt, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      lt = if opts[:error], do: {value, opts}, else: value
      %{schema | lt: lt}
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
