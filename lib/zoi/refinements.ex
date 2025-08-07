defmodule Zoi.Refinements do
  @moduledoc false

  def refine(%Zoi.Types.String{}, input, [min: min], opts) do
    if String.length(input) >= min do
      :ok
    else
      {:error, message(opts, "too small: must have at least #{min} characters")}
    end
  end

  def refine(%Zoi.Types.Integer{}, input, [min: min], opts) do
    if input >= min do
      :ok
    else
      {:error, message(opts, "too small: must be at least #{min}")}
    end
  end

  def refine(%Zoi.Types.Float{}, input, [min: min], opts) do
    if input >= min do
      :ok
    else
      {:error, message(opts, "too small: must be at least #{min}")}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [min: min], opts) do
    if length(input) >= min do
      :ok
    else
      {:error, message(opts, "too small: must have at least #{min} items")}
    end
  end

  def refine(%Zoi.Types.String{}, input, [gt: gt], opts) do
    if String.length(input) > gt do
      :ok
    else
      {:error, message(opts, "too small: must have more than #{gt} characters")}
    end
  end

  def refine(%Zoi.Types.Integer{}, input, [gt: gt], opts) do
    if input > gt do
      :ok
    else
      {:error, message(opts, "too small: must be greater than #{gt}")}
    end
  end

  def refine(%Zoi.Types.Float{}, input, [gt: gt], opts) do
    if input > gt do
      :ok
    else
      {:error, message(opts, "too small: must be greater than #{gt}")}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [gt: gt], opts) do
    if length(input) > gt do
      :ok
    else
      {:error, message(opts, "too small: must have more than #{gt} items")}
    end
  end

  def refine(%Zoi.Types.String{}, input, [max: max], opts) do
    if String.length(input) <= max do
      :ok
    else
      {:error, message(opts, "too big: must have at most #{max} characters")}
    end
  end

  def refine(%Zoi.Types.Integer{}, input, [max: max], opts) do
    if input <= max do
      :ok
    else
      {:error, message(opts, "too big: must be at most #{max}")}
    end
  end

  def refine(%Zoi.Types.Float{}, input, [max: max], opts) do
    if input <= max do
      :ok
    else
      {:error, message(opts, "too big: must be at most #{max}")}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [max: max], opts) do
    if length(input) <= max do
      :ok
    else
      {:error, message(opts, "too big: must have at most #{max} items")}
    end
  end

  def refine(%Zoi.Types.String{}, input, [lt: lt], opts) do
    if String.length(input) < lt do
      :ok
    else
      {:error, message(opts, "too big: must have less than #{lt} characters")}
    end
  end

  def refine(%Zoi.Types.Integer{}, input, [lt: lt], opts) do
    if input < lt do
      :ok
    else
      {:error, message(opts, "too big: must be less than #{lt}")}
    end
  end

  def refine(%Zoi.Types.Float{}, input, [lt: lt], opts) do
    if input < lt do
      :ok
    else
      {:error, message(opts, "too big: must be less than #{lt}")}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [lt: lt], opts) do
    if length(input) < lt do
      :ok
    else
      {:error, message(opts, "too big: must have less than #{lt} items")}
    end
  end

  def refine(%Zoi.Types.String{}, input, [length: length], opts) do
    if String.length(input) == length do
      :ok
    else
      {:error, message(opts, "invalid length: must have #{length} characters")}
    end
  end

  def refine(%Zoi.Types.Array{}, input, [length: length], opts) do
    if length(input) == length do
      :ok
    else
      {:error, message(opts, "invalid length: must have #{length} items")}
    end
  end

  def refine(%Zoi.Types.String{}, input, [regex: regex], opts) do
    if String.match?(input, regex) do
      :ok
    else
      {:error, message(opts, "invalid string: must match a pattern #{inspect(regex)}")}
    end
  end

  def refine(%Zoi.Types.String{}, input, [starts_with: prefix], opts) do
    if String.starts_with?(input, prefix) do
      :ok
    else
      {:error, message(opts, "invalid string: must start with '#{prefix}'")}
    end
  end

  def refine(%Zoi.Types.String{}, input, [ends_with: suffix], opts) do
    if String.ends_with?(input, suffix) do
      :ok
    else
      {:error, message(opts, "invalid string: must end with '#{suffix}'")}
    end
  end

  def refine(_schema, _input, _args, _opts) do
    # Default to :ok if there is no type pattern match
    :ok
  end

  defp message(opts, default_message) do
    Keyword.get(opts, :message, default_message)
  end
end
