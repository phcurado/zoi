defmodule Zoi.Types.DateTime do
  @moduledoc false
  use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, coerce: false]

  alias Zoi.Validations

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      gte:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime minimum value"
        ),
      lte:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime maximum value"
        ),
      gt:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime greater than value"
        ),
      lt:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime less than value"
        )
    )
  end

  def new(opts \\ []) do
    {validation_opts, opts} = Keyword.split(opts, [:gte, :lte, :gt, :lt])

    opts
    |> apply_type()
    |> Validations.maybe_set_validation(Validations.Gte, validation_opts[:gte])
    |> Validations.maybe_set_validation(Validations.Lte, validation_opts[:lte])
    |> Validations.maybe_set_validation(Validations.Gt, validation_opts[:gt])
    |> Validations.maybe_set_validation(Validations.Lt, validation_opts[:lt])
  end

  defimpl Zoi.Type do
    def parse(schema, %DateTime{} = input, opts) do
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
      case DateTime.from_iso8601(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, parsed, _offset} ->
          {:ok, parsed}
      end
    end

    defp coerce(schema, input) when is_integer(input) do
      case DateTime.from_unix(input) do
        {:error, _reason} ->
          error(schema)

        {:ok, parsed} ->
          {:ok, parsed}
      end
    end

    defp coerce(schema, _input) do
      error(schema)
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:datetime, error: schema.meta.error)}
    end

    defp validate_constraints(schema, input, opts) do
      [
        {Validations.Gte, schema.gte},
        {Validations.Lte, schema.lte},
        {Validations.Gt, schema.gt},
        {Validations.Lt, schema.lt}
      ]
      |> Validations.run_validations(schema, input, opts)
    end

    def type_spec(_schema, _opts) do
      quote(do: DateTime.t())
    end
  end

  defimpl Zoi.Validations.Gte do
    def validate(schema, input, opts) do
      {min, custom_opts} = schema.gte
      opts = Keyword.merge(opts, custom_opts)

      case DateTime.compare(input, min) do
        :gt -> :ok
        :eq -> :ok
        :lt -> {:error, Zoi.Error.greater_than_or_equal_to(:date, min, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      %{schema | gte: {value, opts}}
    end
  end

  defimpl Zoi.Validations.Lte do
    def validate(schema, input, opts) do
      {max, custom_opts} = schema.lte
      opts = Keyword.merge(opts, custom_opts)

      case DateTime.compare(input, max) do
        :lt -> :ok
        :eq -> :ok
        :gt -> {:error, Zoi.Error.less_than_or_equal_to(:date, max, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      %{schema | lte: {value, opts}}
    end
  end

  defimpl Zoi.Validations.Gt do
    def validate(schema, input, opts) do
      {gt, custom_opts} = schema.gt
      opts = Keyword.merge(opts, custom_opts)

      case DateTime.compare(input, gt) do
        :gt -> :ok
        _ -> {:error, Zoi.Error.greater_than(:date, gt, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      %{schema | gt: {value, opts}}
    end
  end

  defimpl Zoi.Validations.Lt do
    def validate(schema, input, opts) do
      {lt, custom_opts} = schema.lt
      opts = Keyword.merge(opts, custom_opts)

      case DateTime.compare(input, lt) do
        :lt -> :ok
        _ -> {:error, Zoi.Error.less_than(:date, lt, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      %{schema | lt: {value, opts}}
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
