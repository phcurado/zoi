defmodule Zoi.Refinements do
  @moduledoc false

  def refine(input, args, opts, ctx: ctx) do
    do_refine(ctx.schema, input, args, opts)
  end

  # String
  defp do_refine(%Zoi.Types.String{}, input, [gte: min], opts) do
    if String.length(input) >= min do
      :ok
    else
      {:error, message(opts, "too small: must have at least #{min} characters")}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [gt: gt], opts) do
    if String.length(input) > gt do
      :ok
    else
      {:error, message(opts, "too small: must have more than #{gt} characters")}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [lte: max], opts) do
    if String.length(input) <= max do
      :ok
    else
      {:error, message(opts, "too big: must have at most #{max} characters")}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [lt: lt], opts) do
    if String.length(input) < lt do
      :ok
    else
      {:error, message(opts, "too big: must have less than #{lt} characters")}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [length: length], opts) do
    if String.length(input) == length do
      :ok
    else
      {:error, message(opts, "invalid length: must have #{length} characters")}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [regex: regex], opts) do
    # To allow both string and regex input for regex refinement
    regex = Regex.compile!(regex)

    if String.match?(input, regex) do
      :ok
    else
      {:error, message(opts, "invalid string: must match a pattern #{inspect(regex)}")}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [starts_with: prefix], opts) do
    if String.starts_with?(input, prefix) do
      :ok
    else
      {:error, message(opts, "invalid string: must start with '#{prefix}'")}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [ends_with: suffix], opts) do
    if String.ends_with?(input, suffix) do
      :ok
    else
      {:error, message(opts, "invalid string: must end with '#{suffix}'")}
    end
  end

  # Array
  defp do_refine(%Zoi.Types.Array{}, input, [gte: min], opts) do
    if length(input) >= min do
      :ok
    else
      {:error, message(opts, "too small: must have at least #{min} items")}
    end
  end

  defp do_refine(%Zoi.Types.Array{}, input, [gt: gt], opts) do
    if length(input) > gt do
      :ok
    else
      {:error, message(opts, "too small: must have more than #{gt} items")}
    end
  end

  defp do_refine(%Zoi.Types.Array{}, input, [lt: lt], opts) do
    if length(input) < lt do
      :ok
    else
      {:error, message(opts, "too big: must have less than #{lt} items")}
    end
  end

  defp do_refine(%Zoi.Types.Array{}, input, [lte: max], opts) do
    if length(input) <= max do
      :ok
    else
      {:error, message(opts, "too big: must have at most #{max} items")}
    end
  end

  defp do_refine(%Zoi.Types.Array{}, input, [length: length], opts) do
    if length(input) == length do
      :ok
    else
      {:error, message(opts, "invalid length: must have #{length} items")}
    end
  end

  # Numeric
  for numeric_module <- [Integer, Float, Number] do
    @module Module.concat(Zoi.Types, numeric_module)

    defp do_refine(%@module{}, input, [gte: min], opts) do
      if input >= min do
        :ok
      else
        {:error, message(opts, "too small: must be at least #{min}")}
      end
    end

    defp do_refine(%@module{}, input, [gt: gt], opts) do
      if input > gt do
        :ok
      else
        {:error, message(opts, "too small: must be greater than #{gt}")}
      end
    end

    defp do_refine(%@module{}, input, [lte: max], opts) do
      if input <= max do
        :ok
      else
        {:error, message(opts, "too big: must be at most #{max}")}
      end
    end

    defp do_refine(%@module{}, input, [lt: lt], opts) do
      if input < lt do
        :ok
      else
        {:error, message(opts, "too big: must be less than #{lt}")}
      end
    end
  end

  # Dates
  for date_module <- [Date, NaiveDateTime, Time, DateTime] do
    @module Module.concat(Zoi.Types, date_module)
    @date_module date_module

    defp do_refine(%@module{}, input, [gte: min], opts) do
      case @date_module.compare(input, min) do
        :gt -> :ok
        :eq -> :ok
        :lt -> {:error, message(opts, "too small: must be at least #{min}")}
      end
    end

    defp do_refine(%@module{}, input, [gt: gt], opts) do
      case @date_module.compare(input, gt) do
        :gt -> :ok
        _ -> {:error, message(opts, "too small: must be greater than #{gt}")}
      end
    end

    defp do_refine(%@module{}, input, [lte: max], opts) do
      case @date_module.compare(input, max) do
        :lt -> :ok
        :eq -> :ok
        :gt -> {:error, message(opts, "too big: must be at most #{max}")}
      end
    end

    defp do_refine(%@module{}, input, [lt: lt], opts) do
      case @date_module.compare(input, lt) do
        :lt -> :ok
        _ -> {:error, message(opts, "too big: must be less than #{lt}")}
      end
    end
  end

  # Decimal
  if Code.ensure_loaded?(Decimal) do
    defp do_refine(%Zoi.Types.Decimal{}, input, [gte: min], opts) do
      if Decimal.gte?(input, min) do
        :ok
      else
        {:error, message(opts, "too small: must be at least #{min}")}
      end
    end

    defp do_refine(%Zoi.Types.Decimal{}, input, [gt: gt], opts) do
      if Decimal.gt?(input, gt) do
        :ok
      else
        {:error, message(opts, "too small: must be greater than #{gt}")}
      end
    end

    defp do_refine(%Zoi.Types.Decimal{}, input, [lt: lt], opts) do
      if Decimal.lt?(input, lt) do
        :ok
      else
        {:error, message(opts, "too big: must be less than #{lt}")}
      end
    end

    defp do_refine(%Zoi.Types.Decimal{}, input, [lte: max], opts) do
      if Decimal.lte?(input, max) do
        :ok
      else
        {:error, message(opts, "too big: must be at most #{max}")}
      end
    end
  end

  defp do_refine(_schema, _input, _args, _opts) do
    # Default to :ok if there is no type pattern match
    :ok
  end

  defp message(opts, default_message) do
    Keyword.get(opts, :message, default_message)
  end
end
