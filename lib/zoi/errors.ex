defmodule Zoi.Errors do
  @moduledoc false

  alias Zoi.Error

  def merge(errors1, errors2) do
    errors1 ++ errors2
  end

  def add_error(error) do
    add_error([], error)
  end

  def add_error(errors, %Error{} = error) do
    errors ++ [error]
  end

  def add_error(errors, message) when is_binary(message) do
    error = Error.exception(message: message)
    add_error(errors, error)
  end

  def add_error(errors, opts) when is_list(opts) do
    error = Error.exception(opts)
    add_error(errors, error)
  end

  def message(errors) do
    errors
    |> Enum.map_join(", ", & &1.message)
  end
end
