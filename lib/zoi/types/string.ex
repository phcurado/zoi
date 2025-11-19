defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [:min_length, :max_length, :length, coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      Zoi.Types.Keyword.new(
        [
          min_length: Zoi.Types.Integer.new(description: "Minimum length of the string."),
          max_length: Zoi.Types.Integer.new(description: "Maximum length of the string."),
          length: Zoi.Types.Integer.new(description: "Exact length of the string.")
        ],
        strict: true
      )
    )
  end

  def new(opts) do
    schema = apply_type(opts)

    # Ensure length overrides min/max when both are present
    if Keyword.has_key?(opts, :length) do
      Zoi.Validations.Length.set(schema, opts[:length])
    else
      schema
    end
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
      errors =
        [Zoi.Validations.Length, Zoi.Validations.Gte, Zoi.Validations.Lte]
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

    def set(schema, value) do
      %{schema | min_length: value, length: nil}
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

    def set(schema, value) do
      %{schema | max_length: value, length: nil}
    end
  end

  defimpl Zoi.Validations.Length do
    def validate(%{length: nil}, _input, _opts), do: :ok

    def validate(schema, input, opts) do
      if String.length(input) == schema.length do
        :ok
      else
        {:error, Zoi.Error.invalid_length(:string, schema.length, opts)}
      end
    end

    def set(schema, value) do
      %{schema | length: value, min_length: nil, max_length: nil}
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
