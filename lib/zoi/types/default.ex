defmodule Zoi.Types.Default do
  @moduledoc """
  A type that represents a default value for a schema field.
  It is used to provide a default value when the field is not present in the input data.
  """
  use Zoi.Types.Base, fields: [:inner, :value]

  def new(inner, value, opts \\ []) do
    case Zoi.Type.parse(inner, value, opts) do
      {:ok, _} ->
        struct!(__MODULE__, inner: inner, value: value)

      {:error, reason} ->
        raise Zoi.Error,
          message: "default error: #{inspect(reason)}"
    end
  end
end

defimpl Zoi.Type, for: Zoi.Types.Default do
  def parse(%Zoi.Types.Default{value: value}, nil, _opts), do: {:ok, value}

  def parse(%Zoi.Types.Default{inner: schema}, value, opts),
    do: Zoi.Type.parse(schema, value, opts)
end
