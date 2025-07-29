defmodule Zoi.Types.Default do
  @moduledoc """
  A type that represents a default value for a schema field.
  It is used to provide a default value when the field is not present in the input data.
  """

  @type t :: %__MODULE__{inner: Zoi.Type.t(), value: Zoi.input(), meta: Zoi.Types.Base.t()}
  defstruct [:inner, :value, :meta]

  def new(inner, value, opts \\ []) do
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)

    case Zoi.parse(inner, value, opts) do
      {:ok, _} ->
        opts = Keyword.merge(opts, inner: inner, value: value, meta: meta)
        struct!(__MODULE__, opts)

      {:error, reason} ->
        raise Zoi.Error,
          message: "default error: #{inspect(reason)}"
    end
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Default{value: value}, nil, _opts), do: {:ok, value}

    def parse(%Zoi.Types.Default{inner: schema}, value, opts),
      do: Zoi.parse(schema, value, opts)
  end
end
