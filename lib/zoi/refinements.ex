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
    |> Zoi.Validations.Gte.set(min, opts)
    |> Zoi.Validations.Gte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.String{} = schema, input, [lte: max], opts) do
    schema
    |> Zoi.Validations.Lte.set(max, opts)
    |> Zoi.Validations.Lte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.String{} = schema, input, [length: length], opts) do
    schema
    |> Zoi.Validations.Length.set(length, opts)
    |> Zoi.Validations.Length.validate(input, opts)
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
    |> Zoi.Validations.Gte.set(min, opts)
    |> Zoi.Validations.Gte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.Array{} = schema, input, [lte: max], opts) do
    schema
    |> Zoi.Validations.Lte.set(max, opts)
    |> Zoi.Validations.Lte.validate(input, opts)
  end

  defp do_refine(%Zoi.Types.Array{} = schema, input, [length: length], opts) do
    schema
    |> Zoi.Validations.Length.set(length, opts)
    |> Zoi.Validations.Length.validate(input, opts)
  end

  # Numeric types - all use protocols now
  for numeric_module <- [Integer, Float, Number] do
    @module Module.concat(Zoi.Types, numeric_module)

    defp do_refine(%@module{} = schema, input, [gte: min], opts) do
      schema
      |> Zoi.Validations.Gte.set(min, opts)
      |> Zoi.Validations.Gte.validate(input, opts)
    end

    defp do_refine(%@module{} = schema, input, [lte: max], opts) do
      schema
      |> Zoi.Validations.Lte.set(max, opts)
      |> Zoi.Validations.Lte.validate(input, opts)
    end

    defp do_refine(%@module{} = schema, input, [gt: gt], opts) do
      schema
      |> Zoi.Validations.Gt.set(gt, opts)
      |> Zoi.Validations.Gt.validate(input, opts)
    end

    defp do_refine(%@module{} = schema, input, [lt: lt], opts) do
      schema
      |> Zoi.Validations.Lt.set(lt, opts)
      |> Zoi.Validations.Lt.validate(input, opts)
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
    schema
    |> Zoi.Validations.Gte.set(min, opts)
    |> Zoi.Validations.Gte.validate(input, opts)
  end

  defp do_refine(%module{} = schema, input, [lte: max], opts)
       when module in [
              Zoi.Types.Date,
              Zoi.Types.DateTime,
              Zoi.Types.NaiveDateTime,
              Zoi.Types.Time
            ] do
    schema
    |> Zoi.Validations.Lte.set(max, opts)
    |> Zoi.Validations.Lte.validate(input, opts)
  end

  defp do_refine(%module{} = schema, input, [gt: gt], opts)
       when module in [
              Zoi.Types.Date,
              Zoi.Types.DateTime,
              Zoi.Types.NaiveDateTime,
              Zoi.Types.Time
            ] do
    schema
    |> Zoi.Validations.Gt.set(gt, opts)
    |> Zoi.Validations.Gt.validate(input, opts)
  end

  defp do_refine(%module{} = schema, input, [lt: lt], opts)
       when module in [
              Zoi.Types.Date,
              Zoi.Types.DateTime,
              Zoi.Types.NaiveDateTime,
              Zoi.Types.Time
            ] do
    schema
    |> Zoi.Validations.Lt.set(lt, opts)
    |> Zoi.Validations.Lt.validate(input, opts)
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
