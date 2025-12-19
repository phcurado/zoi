defmodule Zoi.Types.Float do
  @moduledoc false

  use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, :multiple_of, coerce: false]

  alias Zoi.Validations

  def opts() do
    error = "invalid type: expected number"

    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      gte:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "float greater than or equal to",
          error: error
        ),
      lte:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "float less than or equal to",
          error: error
        ),
      gt:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "float greater than",
          error: error
        ),
      lt:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "float less than",
          error: error
        ),
      multiple_of:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "float must be multiple of",
          error: error
        )
    )
  end

  def new(opts \\ []) do
    {validation_opts, opts} = Keyword.split(opts, [:gte, :lte, :gt, :lt, :multiple_of])

    opts
    |> apply_type()
    |> Validations.maybe_set_validation(Validations.Gte, validation_opts[:gte])
    |> Validations.maybe_set_validation(Validations.Lte, validation_opts[:lte])
    |> Validations.maybe_set_validation(Validations.Gt, validation_opts[:gt])
    |> Validations.maybe_set_validation(Validations.Lt, validation_opts[:lt])
    |> Validations.maybe_set_validation(Validations.MultipleOf, validation_opts[:multiple_of])
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      with {:ok, parsed} <- parse_type(input, coerce, schema),
           :ok <- validate_constraints(schema, parsed) do
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

    defp validate_constraints(schema, input) do
      [
        {Validations.Gte, schema.gte},
        {Validations.Lte, schema.lte},
        {Validations.Gt, schema.gt},
        {Validations.Lt, schema.lt},
        {Validations.MultipleOf, schema.multiple_of}
      ]
      |> Validations.run_validations(schema, input)
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:float, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: float())
    end
  end

  defimpl Zoi.Validations.Gte do
    def set(schema, value, opts \\ []) do
      %{schema | gte: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      if input >= value do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:number, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Lte do
    def set(schema, value, opts \\ []) do
      %{schema | lte: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      if input <= value do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:number, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Gt do
    def set(schema, value, opts \\ []) do
      %{schema | gt: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      if input > value do
        :ok
      else
        {:error, Zoi.Error.greater_than(:number, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Lt do
    def set(schema, value, opts \\ []) do
      %{schema | lt: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      if input < value do
        :ok
      else
        {:error, Zoi.Error.less_than(:number, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.MultipleOf do
    def set(schema, value, opts \\ []) do
      %{schema | multiple_of: {value, opts}}
    end

    def validate(_schema, input, value, opts) do
      quotient = input / value

      if quotient == Float.floor(quotient) do
        :ok
      else
        {:error, Zoi.Error.multiple_of(value, opts)}
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
        lt: Validations.unwrap_validation(type.lt),
        multiple_of: Validations.unwrap_validation(type.multiple_of)
      ]

      Zoi.Inspect.build(type, opts, extra_fields)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{type: :number}
      |> maybe_add(:minimum, schema.gte)
      |> maybe_add(:maximum, schema.lte)
      |> maybe_add(:exclusiveMinimum, schema.gt)
      |> maybe_add(:exclusiveMaximum, schema.lt)
      |> maybe_add(:multipleOf, schema.multiple_of)
    end

    defp maybe_add(map, _key, nil), do: map
    defp maybe_add(map, key, {value, _opts}), do: Map.put(map, key, value)
  end
end
