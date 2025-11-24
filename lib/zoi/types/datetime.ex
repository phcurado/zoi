defmodule Zoi.Types.DateTime do
  @moduledoc false
  use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, coerce: false]

  alias Zoi.Validations

  def opts() do
    error = "invalid type: expected datetime"

    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      gte:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime minimum value",
          error: error
        ),
      lte:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime maximum value",
          error: error
        ),
      gt:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime greater than value",
          error: error
        ),
      lt:
        Zoi.Opts.constraint_schema(Zoi.Types.DateTime.new([]),
          description: "datetime less than value",
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
    def parse(schema, %DateTime{} = input, _opts) do
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
      quote(do: DateTime.t())
    end
  end

  defimpl Zoi.Validations.Gte do
    def set(schema, value, opts \\ []) do
      %{schema | gte: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      case DateTime.compare(input, value) do
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
      case DateTime.compare(input, value) do
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
      case DateTime.compare(input, value) do
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
      case DateTime.compare(input, value) do
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

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{type: :string, format: :"date-time"}
      |> maybe_add(:minimum, schema.gte)
      |> maybe_add(:maximum, schema.lte)
      |> maybe_add(:exclusiveMinimum, schema.gt)
      |> maybe_add(:exclusiveMaximum, schema.lt)
    end

    defp maybe_add(map, _key, nil), do: map
    defp maybe_add(map, key, {value, _opts}), do: Map.put(map, key, DateTime.to_iso8601(value))
  end
end
