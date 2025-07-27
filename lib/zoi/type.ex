defprotocol Zoi.Type do
  @moduledoc """
  Protocol for defining types in Zoi.
  """

  @doc """
  Parses the `value` according to the `schema`. Responsible for coercion and missing values.
  """
  def parse(schema, input, opts)
end
