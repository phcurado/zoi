defmodule Zoi.Types.Default do
  @moduledoc false
  use Zoi.Type.Def, fields: [:inner, :value]

  def new(inner, value, opts \\ []) do
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)

    case Zoi.parse(inner, value, opts) do
      {:ok, _} ->
        opts = Keyword.merge(opts, inner: inner, value: value, meta: meta)
        struct!(__MODULE__, opts)

      {:error, error} ->
        raise ArgumentError,
              "Invalid default value: #{inspect(value)}. Reason: #{Zoi.Errors.message(error)}"
    end
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Default{value: value}, nil, _opts), do: {:ok, value}

    def parse(%Zoi.Types.Default{inner: schema}, value, opts),
      do: Zoi.parse(schema, value, opts)
  end
end
