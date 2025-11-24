if Code.ensure_loaded?(Decimal) do
  defmodule Zoi.Types.Decimal do
    @moduledoc false

    use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, coerce: false]

    alias Zoi.Validations

    def opts() do
      error = "invalid type: expected decimal"

      Zoi.Opts.meta_opts()
      |> Zoi.Opts.with_coerce()
      |> Zoi.Types.Extend.new(
        gte:
          Zoi.Opts.constraint_schema(Zoi.Types.Decimal.new([]),
            description: "decimal greater than or equal to",
            error: error
          ),
        lte:
          Zoi.Opts.constraint_schema(Zoi.Types.Decimal.new([]),
            description: "decimal less than or equal to",
            error: error
          ),
        gt:
          Zoi.Opts.constraint_schema(Zoi.Types.Decimal.new([]),
            description: "decimal greater than",
            error: error
          ),
        lt:
          Zoi.Opts.constraint_schema(Zoi.Types.Decimal.new([]),
            description: "decimal less than",
            error: error
          )
      )
    end

    def new(opts) do
      {validation_opts, opts} = Keyword.split(opts, [:gte, :lte, :gt, :lt])

      opts
      |> apply_type()
      |> Validations.maybe_set_validation(Validations.Gte, validation_opts[:gte])
      |> Validations.maybe_set_validation(Validations.Lte, validation_opts[:lte])
      |> Validations.maybe_set_validation(Validations.Gt, validation_opts[:gt])
      |> Validations.maybe_set_validation(Validations.Lt, validation_opts[:lt])
    end

    defimpl Zoi.Type do
      import Decimal, only: [is_decimal: 1]

      def parse(schema, input, opts) do
        coerce = Keyword.get(opts, :coerce, schema.coerce)

        with {:ok, parsed} <- parse_type(schema, input, coerce),
             :ok <- validate_constraints(schema, parsed) do
          {:ok, parsed}
        end
      end

      defp parse_type(_schema, input, _coerce) when is_decimal(input), do: {:ok, input}

      defp parse_type(schema, input, true) do
        case Decimal.cast(input) do
          {:ok, decimal} -> {:ok, decimal}
          :error -> error(schema)
        end
      end

      defp parse_type(schema, _input, _coerce), do: error(schema)

      defp validate_constraints(schema, input) do
        [
          {Validations.Gte, schema.gte},
          {Validations.Lte, schema.lte},
          {Validations.Gt, schema.gt},
          {Validations.Lt, schema.lt}
        ]
        |> Validations.run_validations(schema, input)
      end

      defp error(schema) do
        {:error, Zoi.Error.invalid_type(:decimal, error: schema.meta.error)}
      end

      def type_spec(_schema, _opts) do
        quote(do: Decimal.t())
      end
    end

    defimpl Zoi.Validations.Gte do
      def set(schema, value, opts \\ []) do
        %{schema | gte: {value, opts}}
      end

      def validate(_schema, input, value, opts) do
        if Decimal.gte?(input, value) do
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
        if Decimal.lte?(input, value) do
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
        if Decimal.gt?(input, value) do
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
        if Decimal.lt?(input, value) do
          :ok
        else
          {:error, Zoi.Error.less_than(:number, value, opts)}
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
end
