defmodule Zoi.Types.String do
  @moduledoc false
  use Zoi.Type.Def, fields: [:min_length, :max_length, :length, coerce: false]

  alias Zoi.Validations

  def opts() do
    error = "invalid type: expected integer"

    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
    |> Zoi.Types.Extend.new(
      min_length:
        Zoi.Opts.constraint_schema(Zoi.Types.Integer.new([]),
          description: "string minimum length",
          error: error
        ),
      max_length:
        Zoi.Opts.constraint_schema(Zoi.Types.Integer.new([]),
          description: "string maximum length",
          error: error
        ),
      length:
        Zoi.Opts.constraint_schema(Zoi.Types.Integer.new([]),
          description: "string exact length",
          error: error
        )
    )
  end

  def new(opts \\ []) do
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
           :ok <- validate_constraints(schema, parsed) do
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

    defp validate_constraints(schema, input) do
      [
        {Validations.Length, schema.length},
        {Validations.Gte, schema.min_length},
        {Validations.Lte, schema.max_length}
      ]
      |> Validations.run_validations(schema, input)
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_type(:string, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: binary())
    end
  end

  defimpl Zoi.Validations.Gte do
    def set(schema, value, opts \\ []) do
      %{schema | min_length: {value, opts}, length: nil}
    end

    def validate(_schema, input, value, opts) do
      if String.length(input) >= value do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:string, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Lte do
    def set(schema, value, opts \\ []) do
      %{schema | max_length: {value, opts}, length: nil}
    end

    def validate(_schema, input, value, opts) do
      if String.length(input) <= value do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:string, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Length do
    def set(schema, value, opts \\ []) do
      %{schema | length: {value, opts}, min_length: nil, max_length: nil}
    end

    def validate(_schema, input, value, opts) do
      if String.length(input) == value do
        :ok
      else
        {:error, Zoi.Error.invalid_length(:string, value, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Url do
    def validate(_schema, input, opts) do
      uri = URI.parse(input)

      if uri.scheme in ["http", "https"] and uri.host != nil do
        :ok
      else
        {:error, Zoi.Error.invalid_url(input, opts)}
      end
    end
  end

  defimpl Zoi.Validations.StartsWith do
    def validate(_schema, input, prefix, opts) do
      if String.starts_with?(input, prefix) do
        :ok
      else
        {:error, Zoi.Error.invalid_starting_string(prefix, opts)}
      end
    end
  end

  defimpl Zoi.Validations.EndsWith do
    def validate(_schema, input, suffix, opts) do
      if String.ends_with?(input, suffix) do
        :ok
      else
        {:error, Zoi.Error.invalid_ending_string(suffix, opts)}
      end
    end
  end

  defimpl Zoi.Validations.Regex do
    def validate(_schema, input, regex, regex_opts, opts) do
      # To allow both string and regex input for regex refinement
      regex = Regex.compile!(regex, regex_opts)

      if String.match?(input, regex) do
        :ok
      else
        {:error, Zoi.Error.invalid_format(regex, opts)}
      end
    end
  end

  defimpl Inspect do
    alias Zoi.Validations

    def inspect(type, opts) do
      extra_fields = [
        min_length: Validations.unwrap_validation(type.min_length),
        max_length: Validations.unwrap_validation(type.max_length),
        length: Validations.unwrap_validation(type.length)
      ]

      Zoi.Inspect.build(type, opts, extra_fields)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{type: :string}
      |> maybe_add(:minLength, schema.min_length)
      |> maybe_add(:maxLength, schema.max_length)
      |> maybe_add_length(schema.length)
    end

    defp maybe_add(map, _key, nil), do: map
    defp maybe_add(map, key, {value, _opts}), do: Map.put(map, key, value)

    defp maybe_add_length(map, nil), do: map

    defp maybe_add_length(map, {value, _opts}),
      do: map |> Map.put(:minLength, value) |> Map.put(:maxLength, value)
  end
end
