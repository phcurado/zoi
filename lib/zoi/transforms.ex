defmodule Zoi.Transforms do
  @moduledoc false

  def transform(:trim, %Zoi.Types.String{}, input) do
    String.trim(input)
  end

  def transform(:to_downcase, %Zoi.Types.String{}, input) do
    String.downcase(input)
  end

  def transform(:to_upcase, %Zoi.Types.String{}, input) do
    String.upcase(input)
  end
end
