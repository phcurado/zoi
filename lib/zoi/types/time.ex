defmodule Zoi.Types.Time do
  @moduledoc false
  use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, coerce: false]

  alias Zoi.Validations

  def opts() do
    error = "invalid type: expected time"

    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      gte:
        Zoi.Opts.constraint_schema(Zoi.Types.Time.new([]),
          description: "time minimum value",
          error: error
        ),
      lte:
        Zoi.Opts.constraint_schema(Zoi.Types.Time.new([]),
          description: "time maximum value",
          error: error
        ),
      gt:
        Zoi.Opts.constraint_schema(Zoi.Types.Time.new([]),
          description: "time greater than value",
          error: error
        ),
      lt:
        Zoi.Opts.constraint_schema(Zoi.Types.Time.new([]),
          description: "time less than value",
          error: error
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
    def parse(schema, %Time{} = input, _opts) do
      case validate_constraints(schema, input) do
        :ok -> {:ok, input}
        {:error, errors} -> {:error, errors}
      end
    end

    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      with {:ok, parsed} <- maybe_coerce(coerce, schema, input),
           :ok <- validate_constraints(schema, parsed) do
        {:ok, parsed}
      end
    end

    defp maybe_coerce(true, schema, input), do: coerce(schema, input)
    defp maybe_coerce(_false, schema, _input), do: error(schema)

    defp coerce(schema, input) when is_binary(input) do
      case Time.from_iso8601(input) do
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
      {:error, Zoi.Error.invalid_type(:time, error: schema.meta.error)}
    end

    defp validate_constraints(schema, input) do
      [
        {Validations.Gte, schema.gte},
        {Validations.Lte, schema.lte},
        {Validations.Gt, schema.gt},
        {Validations.Lt, schema.lt}
      ]
      |> Validations.run_validations(schema, input)
    end

    def type_spec(_schema, _opts) do
      quote(do: Time.t())
    end
  end

  defimpl Zoi.Validations.Gte do
    def set(schema, value, opts \\ []) do
      %{schema | gte: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      case Time.compare(input, value) do
        :gt -> :ok
        :eq -> :ok
        :lt -> {:error, Zoi.Error.greater_than_or_equal_to(:date, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Lte do
    def set(schema, value, opts \\ []) do
      %{schema | lte: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      case Time.compare(input, value) do
        :lt -> :ok
        :eq -> :ok
        :gt -> {:error, Zoi.Error.less_than_or_equal_to(:date, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Gt do
    def set(schema, value, opts \\ []) do
      %{schema | gt: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      case Time.compare(input, value) do
        :gt -> :ok
        _ -> {:error, Zoi.Error.greater_than(:date, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Lt do
    def set(schema, value, opts \\ []) do
      %{schema | lt: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      case Time.compare(input, value) do
        :lt -> :ok
        _ -> {:error, Zoi.Error.less_than(:date, value, opts)}
      end
    end
  end

  defimpl Inspect do
    alias Zoi.Validations

    def inspect(type, opts) do
      extra_fields = [
        gte: Validations.unwrap_validation(type.gte),
        lte: Validations.unwrap_validation(type.lte),
        gt: Validations.unwrap_validation(type.gt),
        lt: Validations.unwrap_validation(type.lt)
      ]

      Zoi.Inspect.build(type, opts, extra_fields)
    end
  end
end
