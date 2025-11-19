defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [:min_length, :max_length, coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      Zoi.Types.Keyword.new(
        [
          min_length: Zoi.Types.Integer.new(description: "Minimum length of the string."),
          max_length: Zoi.Types.Integer.new(description: "Maximum length of the string.")
        ],
        strict: true
      )
    )
  end

  def new(opts) do
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

    defp parse_type(input, coerce, schema) do
      cond do
        is_binary(input) -> {:ok, input}
        coerce -> {:ok, to_string(input)}
        true -> error(schema)
      end
    end

    defp validate_constraints(schema, input, opts) do
      with :ok <- Zoi.Validations.Gte.validate(schema, input, opts),
           :ok <- Zoi.Validations.Lte.validate(schema, input, opts) do
        :ok
      end
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:string, error: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: binary())
    end
  end

  defimpl Zoi.Validations.Gte do
    def validate(%{min_length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      if String.length(input) >= schema.min_length do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:string, schema.min_length, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Lte do
    def validate(%{max_length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      if String.length(input) <= schema.max_length do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:string, schema.max_length, opts)}
      end
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
