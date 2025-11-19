defmodule Zoi.Errors do
  @moduledoc false

  alias Zoi.Error

  @type t :: list(Error.t())

  @spec merge(t(), t()) :: t()
  def merge(errors1, errors2) do
    errors1 ++ errors2
  end

  @spec add_error(Zoi.Context.error()) :: t()
  def add_error(error) do
    add_error([], error)
  end

  def add_error(errors, %Error{} = error) do
    errors ++ [error]
  end

  def add_error(errors, message) when is_binary(message) do
    error = Error.custom_error(issue: {message, []})
    add_error(errors, error)
  end

  def add_error(errors, error) when is_map(error) do
    error = Error.new(error)
    add_error(errors, error)
  end

  def add_error(errors_1, errors_2) when is_list(errors_2) do
    errors_1 ++ errors_2
  end
end
