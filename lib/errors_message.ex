defmodule Zoi.Errors.Message do
  @moduledoc """
  All errors message, this is a temporary module to analise the errors
  """
  @invalid_type_errors [
    "invalid type: must be an array",
    "invalid type: must be an atom",
    "invalid type: must be a boolean",
    "invalid type: must be a date",
    "invalid type: must be a datetime",
    "invalid type: must be a decimal",
    "invalid option, must be one of: %{options}",
    "invalid type: must be a float",
    "invalid type: must be an integer",
    "invalid type: must be a keyword list",
    "invalid type: does not match literal",
    "invalid type: must be a map",
    "invalid type: must be a naive datetime",
    "invalid type: must be nil",
    "invalid type: must be a number",
    "invalid type: must be a map",
    "invalid type: must be a string",
    "invalid type: must be a string boolean",
    "invalid type: must be a struct",
    "invalid type: must be a time",
    # needs to change to element(s)
    "invalid type: must be a tuple with %{count} elements"
  ]

  @invalid_type_errors_improved [
    # generic, will be used on all types
    "invalid type: expected %{expected}",
    # enum
    "invalid option, must be one of: %{options}",
    # fixed element size
    "invalid type: expected %{type} with %{count} elements"
  ]

  # Regexes errors
  # TODO: map regex errors
  @invalid_regex []

  # range errors (length, min, max, etc)

  ## Error codes
  @error_codes [
    # Suggested set (atoms, stable):
    :invalid_type,
    :invalid_literal,
    :unrecognized_keys,
    :invalid_enum_value,
    :invalid_date,
    :invalid_string,
    :greater_than,
    :less_than,
    :greater_than_or_equal_to,
    :less_than_or_equal_to,
    :invalid_format,
    :custom
  ]
end
