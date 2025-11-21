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
    Zoi.Validations.Gte.validate(schema, input, min, opts)
  end

  defp do_refine(%Zoi.Types.String{} = schema, input, [lte: max], opts) do
    Zoi.Validations.Lte.validate(schema, input, max, opts)
  end

  defp do_refine(%Zoi.Types.String{} = schema, input, [length: length], opts) do
    Zoi.Validations.Length.validate(schema, input, length, opts)
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
    Zoi.Validations.Gte.validate(schema, input, min, opts)
  end

  defp do_refine(%Zoi.Types.Array{} = schema, input, [lte: max], opts) do
    Zoi.Validations.Lte.validate(schema, input, max, opts)
  end

  defp do_refine(%Zoi.Types.Array{} = schema, input, [length: length], opts) do
    Zoi.Validations.Length.validate(schema, input, length, opts)
  end

  # Numeric types - all use protocols now
  for numeric_module <- [Integer, Float, Number] do
    @module Module.concat(Zoi.Types, numeric_module)

    defp do_refine(%@module{} = schema, input, [gte: min], opts) do
      Zoi.Validations.Gte.validate(schema, input, min, opts)
    end

    defp do_refine(%@module{} = schema, input, [lte: max], opts) do
      Zoi.Validations.Lte.validate(schema, input, max, opts)
    end

    defp do_refine(%@module{} = schema, input, [gt: gt], opts) do
      Zoi.Validations.Gt.validate(schema, input, gt, opts)
    end

    defp do_refine(%@module{} = schema, input, [lt: lt], opts) do
      Zoi.Validations.Lt.validate(schema, input, lt, opts)
    end
  end

  # Date - uses protocols
  defp do_refine(%module{} = schema, input, [gte: min], opts)
       when module in [
              Zoi.Types.Date,
              Zoi.Types.DateTime,
              Zoi.Types.NaiveDateTime,
              Zoi.Types.Time
            ] do
    Zoi.Validations.Gte.validate(schema, input, min, opts)
  end

  defp do_refine(%module{} = schema, input, [lte: max], opts)
       when module in [
              Zoi.Types.Date,
              Zoi.Types.DateTime,
              Zoi.Types.NaiveDateTime,
              Zoi.Types.Time
            ] do
    Zoi.Validations.Lte.validate(schema, input, max, opts)
  end

  defp do_refine(%module{} = schema, input, [gt: gt], opts)
       when module in [
              Zoi.Types.Date,
              Zoi.Types.DateTime,
              Zoi.Types.NaiveDateTime,
              Zoi.Types.Time
            ] do
    Zoi.Validations.Gt.validate(schema, input, gt, opts)
  end

  defp do_refine(%module{} = schema, input, [lt: lt], opts)
       when module in [
              Zoi.Types.Date,
              Zoi.Types.DateTime,
              Zoi.Types.NaiveDateTime,
              Zoi.Types.Time
            ] do
    Zoi.Validations.Lt.validate(schema, input, lt, opts)
  end

  # Decimal
  if Code.ensure_loaded?(Decimal) do
    defp do_refine(%Zoi.Types.Decimal{} = schema, input, [gte: min], opts) do
      Zoi.Validations.Gte.validate(schema, input, min, opts)
    end

    defp do_refine(%Zoi.Types.Decimal{} = schema, input, [gt: gt], opts) do
      Zoi.Validations.Gt.validate(schema, input, gt, opts)
    end

    defp do_refine(%Zoi.Types.Decimal{} = schema, input, [lt: lt], opts) do
      Zoi.Validations.Lt.validate(schema, input, lt, opts)
    end

    defp do_refine(%Zoi.Types.Decimal{} = schema, input, [lte: max], opts) do
      Zoi.Validations.Lte.validate(schema, input, max, opts)
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
