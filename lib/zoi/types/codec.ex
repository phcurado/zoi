defmodule Zoi.Types.Codec do
  @moduledoc false

  use Zoi.Type.Def, fields: [:from, :to, :decode, :encode]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Types.Extend.new(
      decode:
        Zoi.Types.Any.new(
          description:
            "A 1-arity function that transforms from the `from` schema to the `to` schema."
        ),
      encode:
        Zoi.Types.Any.new(
          description:
            "A 1-arity function that transforms from the `to` schema to the `from` schema."
        )
    )
  end

  def new(opts, from, to) do
    {decode, opts} = Keyword.pop!(opts, :decode)
    {encode, opts} = Keyword.pop!(opts, :encode)
    validate_function!(:decode, decode)
    validate_function!(:encode, encode)

    apply_type([from: from, to: to, decode: decode, encode: encode] ++ opts)
  end

  defp validate_function!(name, fun) do
    unless is_function(fun, 1) do
      raise ArgumentError,
            "expected :#{name} to be a 1-arity function, got: #{inspect(fun)}"
    end
  end

  def encode(%__MODULE__{} = codec, input, opts \\ []) do
    with {:ok, validated_input} <- Zoi.parse(codec.to, input, opts),
         {:ok, encoded} <- apply_encode(codec, validated_input) do
      Zoi.parse(codec.from, encoded, opts)
    end
  end

  defp apply_encode(codec, value) do
    case codec.encode.(value) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, reason} -> {:error, [Zoi.Error.new(message: reason)]}
      encoded -> {:ok, encoded}
    end
  end

  defimpl Zoi.Type do
    def parse(schema, input, opts) do
      with {:ok, validated_input} <- Zoi.parse(schema.from, input, opts),
           {:ok, decoded} <- apply_decode(schema, validated_input) do
        Zoi.parse(schema.to, decoded, opts)
      end
    end

    defp apply_decode(schema, value) do
      case schema.decode.(value) do
        {:error, reason} -> {:error, Zoi.Error.new(message: reason)}
        {:ok, decoded} -> {:ok, decoded}
        decoded -> {:ok, decoded}
      end
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(schema, opts) do
      Zoi.TypeSpec.spec(schema.to, opts)
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      extra_fields = [
        from: Inspect.inspect(type.from, opts),
        to: Inspect.inspect(type.to, opts)
      ]

      Zoi.Inspect.build(type, opts, extra_fields)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      Zoi.JSONSchema.encode_schema(schema.from)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(%{to: to}) do
      Zoi.Describe.Encoder.encode(to)
    end
  end
end
