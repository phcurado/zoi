defmodule Zoi.Refinements do
  @moduledoc false

  def refine(%Zoi.Types.String{}, input, [min: min], _opts) do
    if String.length(input) >= min do
      :ok
    else
      {:error, "too small: must have at least #{min} characters"}
    end
  end

  def refine(%Zoi.Types.Integer{}, input, [min: min], _opts) do
    if input >= min do
      :ok
    else
      {:error, "too small: must be at least #{min}"}
    end
  end

  def refine(%Zoi.Types.Float{}, input, [min: min], _opts) do
    if input >= min do
      :ok
    else
      {:error, "too small: must be at least #{min}"}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [min: min], _opts) do
    if length(input) >= min do
      :ok
    else
      {:error, "too small: must have at least #{min} items"}
    end
  end

  def refine(%Zoi.Types.String{}, input, [max: max], _opts) do
    if String.length(input) <= max do
      :ok
    else
      {:error, "too big: must have at most #{max} characters"}
    end
  end

  def refine(%Zoi.Types.Integer{}, input, [max: max], _opts) do
    if input <= max do
      :ok
    else
      {:error, "too big: must be at most #{max}"}
    end
  end

  def refine(%Zoi.Types.Float{}, input, [max: max], _opts) do
    if input <= max do
      :ok
    else
      {:error, "too big: must be at most #{max}"}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [max: max], _opts) do
    if length(input) <= max do
      :ok
    else
      {:error, "too big: must have at most #{max} items"}
    end
  end

  def refine(%Zoi.Types.String{}, input, [length: length], _opts) do
    if String.length(input) == length do
      :ok
    else
      {:error, "Invalid length: must have #{length} characters"}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [length: length], _opts) do
    if length(input) == length do
      :ok
    else
      {:error, "Invalid length: must have #{length} items"}
    end
  end

  def refine(%Zoi.Types.String{}, input, [regex: regex], opts) do
    message =
      Keyword.get(opts, :message, "Invalid string: must match a patterh #{inspect(regex)}")

    if String.match?(input, regex) do
      :ok
    else
      {:error, message}
    end
  end

  def refine(%Zoi.Types.String{}, input, [starts_with: prefix], _opts) do
    if String.starts_with?(input, prefix) do
      :ok
    else
      {:error, "Invalid string: must start with '#{prefix}'"}
    end
  end

  def refine(%Zoi.Types.String{}, input, [ends_with: suffix], _opts) do
    if String.ends_with?(input, suffix) do
      :ok
    else
      {:error, "Invalid string: must end with '#{suffix}'"}
    end
  end

  def refine(_schema, _input, _args, _opts) do
    # Default to :ok if there is no type pattern match
    :ok
  end
end
