defmodule Zoi.Errors do
  @moduledoc false

  alias Zoi.Error

  @type t :: list(Error.t())
  @type error :: Error.t() | binary() | list(keyword())

  @spec merge(t(), t()) :: t()
  def merge(errors1, errors2) do
    errors1 ++ errors2
  end

  @spec add_error(error()) :: t()
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

  def add_error(errors, error) when is_map(error) do
    error = Error.exception(error)
    add_error(errors, error)
  end

  def add_error(errors_1, errors_2) when is_list(errors_2) do
    errors_1 ++ errors_2
  end

  def message(errors) do
    errors
    |> Enum.map_join(", ", & &1.message)
  end
end
