defmodule Zoi.Refinements do
  @moduledoc false

  def refine(input, args, opts, ctx: ctx) do
    do_refine(ctx.schema, input, args, opts)
  end

  # String URL validation
  defp do_refine(%Zoi.Types.String{}, input, [:url], opts) do
    uri = URI.parse(input)

    if uri.scheme in ["http", "https"] and uri.host != nil do
      :ok
    else
      {:error, Zoi.Error.invalid_url(input, opts)}
    end
  end

  # String regex validation
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

  # Generic one_of validation
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
