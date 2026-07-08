defmodule Zoi.Types.MapSet do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner, coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
  end

  def new(inner, opts) when is_struct(inner) do
    apply_type([inner: inner] ++ opts)
  end

  def new(inner, _opts) do
    raise ArgumentError,
          "you should use a valid Zoi schema, got: #{inspect(inner)}"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.MapSet{} = schema, %MapSet{} = input, opts) do
      input
      |> MapSet.to_list()
      |> parse_values(schema, opts)
    end

    def parse(%Zoi.Types.MapSet{coerce: true} = schema, input, opts) when is_list(input) do
      parse_values(input, schema, opts)
    end

    def parse(schema, _input, _opts) do
      {:error, Zoi.Error.invalid_type(:mapset, error: schema.meta.error)}
    end

    defp parse_values(input, schema, opts) do
      input
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {input, index}, {parsed, errors} ->
        ctx = Zoi.Context.new(schema.inner, input) |> Zoi.Context.add_path([index])
        ctx = Zoi.Context.parse(ctx, opts)

        if ctx.valid? do
          {[{index, ctx.parsed} | parsed], errors}
        else
          new_errors =
            Enum.reduce(ctx.errors, errors, fn error, acc ->
              [Zoi.Error.prepend_path(error, [index]) | acc]
            end)

          parsed =
            if is_nil(ctx.parsed) do
              parsed
            else
              [{index, ctx.parsed} | parsed]
            end

          {parsed, new_errors}
        end
      end)
      |> finalize_result()
    end

    defp finalize_result({parsed, []}) do
      values = parsed |> Enum.reverse() |> Enum.map(fn {_index, value} -> value end)
      {:ok, MapSet.new(values)}
    end

    defp finalize_result({parsed, errors}) do
      values = parsed |> Enum.reverse() |> Enum.map(fn {_index, value} -> value end)
      {:error, Enum.reverse(errors), MapSet.new(values)}
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.MapSet{inner: %Zoi.Types.Any{}}, _opts) do
      quote do
        MapSet.t()
      end
    end

    def spec(%Zoi.Types.MapSet{inner: inner}, opts) do
      inner_spec = Zoi.type_spec(inner, opts)

      quote do
        MapSet.t(unquote(inner_spec))
      end
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts, inner: Inspect.inspect(type.inner, opts))
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(%{inner: %Zoi.Types.Any{}}) do
      %{type: :array, uniqueItems: true}
    end

    def encode(schema) do
      %{type: :array, items: Zoi.JSONSchema.encode_schema(schema.inner), uniqueItems: true}
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(%{inner: inner}) do
      "MapSet of #{Zoi.Describe.Encoder.encode(inner)}"
    end
  end
end
