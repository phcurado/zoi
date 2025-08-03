defmodule Zoi.Refinements do
  @moduledoc false

  def validate(:min, %Zoi.Types.String{}, input, min: min) do
    if String.length(input) >= min do
      :ok
    else
      {:error, "minimum length is #{min}"}
    end
  end

  def validate(:min, %Zoi.Types.Integer{}, input, min: min) do
    if input >= min do
      :ok
    else
      {:error, "minimum value is #{min}"}
    end
  end

  def validate(:min, %Zoi.Types.Float{}, input, min: min) do
    if input >= min do
      :ok
    else
      {:error, "minimum value is #{min}"}
    end
  end

  def validate(:max, %Zoi.Types.String{}, input, max: max) do
    if String.length(input) <= max do
      :ok
    else
      {:error, "maximum length is #{max}"}
    end
  end

  def validate(:max, %Zoi.Types.Integer{}, input, max: max) do
    if input <= max do
      :ok
    else
      {:error, "maximum value is #{max}"}
    end
  end

  def validate(:max, %Zoi.Types.Float{}, input, max: max) do
    if input <= max do
      :ok
    else
      {:error, "maximum value is #{max}"}
    end
  end

  def validate(:length, %Zoi.Types.String{}, input, length: length) do
    if String.length(input) == length do
      :ok
    else
      {:error, "length must be #{length}"}
    end
  end

  def validate(:regex, %Zoi.Types.String{}, input, opts) do
    regex = Keyword.fetch!(opts, :regex)
    message = Keyword.get(opts, :message, "regex does not match")

    if String.match?(input, regex) do
      :ok
    else
      {:error, message}
    end
  end

  def validate(:starts_with, %Zoi.Types.String{}, input, prefix: prefix) do
    if String.starts_with?(input, prefix) do
      :ok
    else
      {:error, "must start with '#{prefix}'"}
    end
  end

  def validate(:ends_with, %Zoi.Types.String{}, input, suffix: suffix) do
    if String.ends_with?(input, suffix) do
      :ok
    else
      {:error, "must end with '#{suffix}'"}
    end
  end
end
