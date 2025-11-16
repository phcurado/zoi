defmodule Zoi.Types.Default do
  @moduledoc false
  use Zoi.Type.Def, fields: [:inner, :value]

  def opts() do
    Zoi.Types.Keyword.new(
      [
        description: Zoi.Opts.description(),
        example: Zoi.Opts.example(),
        metadata: Zoi.Opts.metadata(),
        error: Zoi.Opts.error()
      ],
      []
    )
  end

  def new(inner, value, opts \\ []) do
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)

    # case Zoi.parse(inner, value, opts) do
    #   {:ok, _} ->
    #     opts = Keyword.merge(opts, inner: inner, value: value, meta: meta)
    #     struct!(__MODULE__, opts)
    #
    #   {:error, error} ->
    #     raise ArgumentError,
    #           "Invalid default value: #{inspect(value)}. Reason: #{Zoi.Errors.message(error)}"
    # end

    opts = Keyword.merge(opts, inner: inner, value: value, meta: meta)
    struct!(__MODULE__, opts)
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Default{value: value}, nil, _opts) do
      {:ok, value}
    end

    def parse(%Zoi.Types.Default{inner: schema}, value, opts) do
      Zoi.parse(schema, value, opts)
    end

    def type_spec(%Zoi.Types.Default{inner: schema}, opts) do
      Zoi.Type.type_spec(schema, opts)
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
