defmodule Zoi.Refinements do
  @moduledoc false

  def validate(%Zoi.Types.String{}, input, [min: min], _opts) do
    if String.length(input) >= min do
      :ok
    else
      {:error, "minimum length is #{min}"}
    end
  end

  def validate(%Zoi.Types.Integer{}, input, [min: min], _opts) do
    if input >= min do
      :ok
    else
      {:error, "minimum value is #{min}"}
    end
  end

  def validate(%Zoi.Types.Float{}, input, [min: min], _opts) do
    if input >= min do
      :ok
    else
      {:error, "minimum value is #{min}"}
    end
  end

  def validate(%Zoi.Types.String{}, input, [max: max], _opts) do
    if String.length(input) <= max do
      :ok
    else
      {:error, "maximum length is #{max}"}
    end
  end

  def validate(%Zoi.Types.Integer{}, input, [max: max], _opts) do
    if input <= max do
      :ok
    else
      {:error, "maximum value is #{max}"}
    end
  end

  def validate(%Zoi.Types.Float{}, input, [max: max], _opts) do
    if input <= max do
      :ok
    else
      {:error, "maximum value is #{max}"}
    end
  end

  def validate(%Zoi.Types.String{}, input, [length: length], _opts) do
    if String.length(input) == length do
      :ok
    else
      {:error, "length must be #{length}"}
    end
  end

  def validate(%Zoi.Types.String{}, input, [regex: regex], opts) do
    message = Keyword.get(opts, :message, "regex does not match")

    if String.match?(input, regex) do
      :ok
    else
      {:error, message}
    end
  end

  def validate(%Zoi.Types.String{}, input, [starts_with: prefix], _opts) do
    if String.starts_with?(input, prefix) do
      :ok
    else
      {:error, "must start with '#{prefix}'"}
    end
  end

  def validate(%Zoi.Types.String{}, input, [ends_with: suffix], _opts) do
    if String.ends_with?(input, suffix) do
      :ok
    else
      {:error, "must end with '#{suffix}'"}
    end
  end
end
