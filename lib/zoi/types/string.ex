defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [:min_length, :max_length, :length, coerce: false]

  alias Zoi.Validations

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      min_length:
        Zoi.Opts.constraint_schema(Zoi.Types.Integer.new([]),
          description: "string minimum length"
        ),
      max_length:
        Zoi.Opts.constraint_schema(Zoi.Types.Integer.new([]),
          description: "string maximum length"
        ),
      length:
        Zoi.Opts.constraint_schema(Zoi.Types.Integer.new([]), description: "string exact length")
    )
  end

  def new(opts) do
    {validation_opts, opts} = Keyword.split(opts, [:min_length, :max_length, :length])

    opts
    |> apply_type()
    |> Validations.maybe_set_validation(Validations.Gte, validation_opts[:min_length])
    |> Validations.maybe_set_validation(Validations.Lte, validation_opts[:max_length])
    |> Validations.maybe_set_validation(Validations.Length, validation_opts[:length])
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      with {:ok, parsed} <- parse_type(input, coerce, schema),
           :ok <- validate_constraints(schema, parsed, opts) do
        {:ok, parsed}
      end
    end

    defp parse_type(input, coerce, schema) do
      cond do
        is_binary(input) -> {:ok, input}
        coerce -> {:ok, to_string(input)}
        true -> error(schema)
      end
    end

    defp validate_constraints(schema, input, opts) do
      [
        {Validations.Length, schema.length},
        {Validations.Gte, schema.min_length},
        {Validations.Lte, schema.max_length}
      ]
      |> Validations.run_validations(schema, input, opts)
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:string, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: binary())
    end
  end

  defimpl Zoi.Validations.Gte do
    def validate(schema, input, opts) do
      {min, custom_opts} = schema.min_length
      opts = Keyword.merge(opts, custom_opts)

      if String.length(input) >= min do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:string, min, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      %{schema | min_length: {value, opts}, length: nil}
    end
  end

  defimpl Zoi.Validations.Lte do
    def validate(schema, input, opts) do
      {max, custom_opts} = schema.max_length
      opts = Keyword.merge(opts, custom_opts)

      if String.length(input) <= max do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:string, max, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      %{schema | max_length: {value, opts}, length: nil}
    end
  end

  defimpl Zoi.Validations.Length do
    def validate(schema, input, opts) do
      {length, custom_opts} = schema.length
      opts = Keyword.merge(opts, custom_opts)

      if String.length(input) == length do
        :ok
      else
        {:error, Zoi.Error.invalid_length(:string, length, opts)}
      end
    end

    def set(schema, value, opts \\ []) do
      %{schema | length: {value, opts}, min_length: nil, max_length: nil}
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
