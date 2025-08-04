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
end
