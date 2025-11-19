defmodule Zoi.Refinements do
  @moduledoc false

  def refine(input, args, opts, ctx: ctx) do
    do_refine(ctx.schema, input, args, opts)
  end

  # String
  defp do_refine(%Zoi.Types.String{}, input, [:url], opts) do
    uri = URI.parse(input)

    if uri.scheme in ["http", "https"] and uri.host != nil do
      :ok
    else
      {:error, Zoi.Error.invalid_url(input, opts)}
    end
  end

  defp do_refine(%Zoi.Types.String{} = schema, input, [gte: min], opts) do
    schema
    |> Zoi.Validations.Gte.set(min)
    |> Zoi.Validations.Gte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.String{} = schema, input, [lte: max], opts) do
    schema
    |> Zoi.Validations.Lte.set(max)
    |> Zoi.Validations.Lte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.String{}, input, [length: length], opts) do
    if String.length(input) == length do
      :ok
    else
      {:error, Zoi.Error.invalid_length(:string, length, opts)}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [regex: regex, opts: regex_opts], opts) do
    # To allow both string and regex input for regex refinement
    regex = Regex.compile!(regex, regex_opts)

    if String.match?(input, regex) do
      :ok
    else
      {:error, Zoi.Error.invalid_format(regex, opts)}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [starts_with: prefix], opts) do
    if String.starts_with?(input, prefix) do
      :ok
    else
      {:error, Zoi.Error.invalid_starting_string(prefix, opts)}
    end
  end

  defp do_refine(%Zoi.Types.String{}, input, [ends_with: suffix], opts) do
    if String.ends_with?(input, suffix) do
      :ok
    else
      {:error, Zoi.Error.invalid_ending_string(suffix, opts)}
    end
  end

  # Array
  defp do_refine(%Zoi.Types.Array{} = schema, input, [gte: min], opts) do
    schema
    |> Zoi.Validations.Gte.set(min)
    |> Zoi.Validations.Gte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.Array{} = schema, input, [lte: max], opts) do
    schema
    |> Zoi.Validations.Lte.set(max)
    |> Zoi.Validations.Lte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.Array{} = schema, input, [length: length], opts) do
    schema
    |> Zoi.Validations.Length.set(length)
    |> Zoi.Validations.Length.validate(input, opts)
  end

  # Numeric
  for numeric_module <- [Integer, Float, Number] do
    @module Module.concat(Zoi.Types, numeric_module)

    defp do_refine(%@module{}, input, [gte: min], opts) do
      if input >= min do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:number, min, opts)}
      end
    end

    defp do_refine(%@module{}, input, [gt: gt], opts) do
      if input > gt do
        :ok
      else
        {:error, Zoi.Error.greater_than(:number, gt, opts)}
      end
    end

    defp do_refine(%@module{}, input, [lte: max], opts) do
      if input <= max do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:number, max, opts)}
      end
    end

    defp do_refine(%@module{}, input, [lt: lt], opts) do
      if input < lt do
        :ok
      else
        {:error, Zoi.Error.less_than(:number, lt, opts)}
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
        :lt -> {:error, Zoi.Error.greater_than_or_equal_to(:date, min, opts)}
      end
    end

    defp do_refine(%@module{}, input, [gt: gt], opts) do
      case @date_module.compare(input, gt) do
        :gt -> :ok
        _ -> {:error, Zoi.Error.greater_than(:date, gt, opts)}
      end
    end

    defp do_refine(%@module{}, input, [lte: max], opts) do
      case @date_module.compare(input, max) do
        :lt -> :ok
        :eq -> :ok
        :gt -> {:error, Zoi.Error.less_than_or_equal_to(:date, max, opts)}
      end
    end

    defp do_refine(%@module{}, input, [lt: lt], opts) do
      case @date_module.compare(input, lt) do
        :lt -> :ok
        _ -> {:error, Zoi.Error.less_than(:date, lt, opts)}
      end
    end
  end

  # Decimal
  if Code.ensure_loaded?(Decimal) do
    defp do_refine(%Zoi.Types.Decimal{}, input, [gte: min], opts) do
      if Decimal.gte?(input, min) do
        :ok
      else
        {:error, Zoi.Error.greater_than_or_equal_to(:number, min, opts)}
      end
    end

    defp do_refine(%Zoi.Types.Decimal{}, input, [gt: gt], opts) do
      if Decimal.gt?(input, gt) do
        :ok
      else
        {:error, Zoi.Error.greater_than(:number, gt, opts)}
      end
    end

    defp do_refine(%Zoi.Types.Decimal{}, input, [lt: lt], opts) do
      if Decimal.lt?(input, lt) do
        :ok
      else
        {:error, Zoi.Error.less_than(:number, lt, opts)}
      end
    end

    defp do_refine(%Zoi.Types.Decimal{}, input, [lte: max], opts) do
      if Decimal.lte?(input, max) do
        :ok
      else
        {:error, Zoi.Error.less_than_or_equal_to(:number, max, opts)}
      end
    end
  end

  defp do_refine(_schema, input, [one_of: values], opts) do
    if input in values do
      :ok
    else
      {:error, Zoi.Error.not_in_values(values, opts)}
    end
  end

  defp do_refine(_schema, _input, _args, _opts) do
    # Default to :ok if there is no type pattern match
    :ok
  end
end
