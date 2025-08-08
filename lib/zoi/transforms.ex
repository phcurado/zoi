defmodule Zoi.Transforms do
  @moduledoc false

  def transform(schema, input, transforms, opts \\ [])

  def transform(%Zoi.Types.String{}, input, [:trim], _opts) do
    String.trim(input)
  end

  def transform(%Zoi.Types.String{}, input, [:to_downcase], _opts) do
    String.downcase(input)
  end

  def transform(%Zoi.Types.String{}, input, [:to_upcase], _opts) do
    String.upcase(input)
  end

  def transform(%Zoi.Types.Datetime{format: %Zoi.Types.String{}}, input, [:to_datetime], _opts) do
    case DateTime.from_iso8601(input) do
      {:ok, parsed, _offset} -> {:ok, parsed}
      {:error, atom} -> {:error, "Invalid iso string datetime: #{atom}"}
    end
  end

  def transform(%Zoi.Types.Datetime{format: %Zoi.Types.Integer{}}, input, [:to_datetime], _opts) do
    case DateTime.from_unix(input) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, atom} -> {:error, "Invalid unix timestamp: #{atom}"}
    end
  end

  def transform(_schema, input, _args, _opts) do
    # Default to the input if there is no type pattern match
    {:ok, input}
  end
end
