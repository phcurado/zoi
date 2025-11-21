defmodule Zoi.Types.Number do
  @moduledoc false
  use Zoi.Type.Def, fields: [:gte, :lte, :gt, :lt, coerce: false]

  alias Zoi.Validations

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      gte:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "number greater than or equal to"
        ),
      lte:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "number less than or equal to"
        ),
      gt:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "number greater than"
        ),
      lt:
        Zoi.Opts.constraint_schema(Zoi.Types.Number.new([]),
          description: "number less than"
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
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      with {:ok, parsed} <- parse_type(input, coerce, schema),
           :ok <- validate_constraints(schema, parsed) do
        {:ok, parsed}
      end
    end

    defp parse_type(input, _coerce, _schema) when is_number(input), do: {:ok, input}

    defp parse_type(input, true, schema) when is_binary(input) do
      case Integer.parse(input) do
        {number, ""} ->
          {:ok, number}

        {_number, _rest} ->
          case Float.parse(input) do
            {float, ""} -> {:ok, float}
            _error -> error(schema)
          end

        _error ->
          error(schema)
      end
    end

    defp parse_type(_input, _coerce, schema), do: error(schema)

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
      {:error, Zoi.Error.invalid_type(:number, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: number())
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

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
