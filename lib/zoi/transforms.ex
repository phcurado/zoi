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

  def transform(_schema, input, _args, _opts) do
    # Default to the input if there is no type pattern match
    {:ok, input}
  end
end
