defprotocol Zoi.Describe.Encoder do
  @moduledoc false

  @doc """
  Returns a human-readable type description string for the given schema.
  Used by `Zoi.describe/1` to generate documentation strings for schema fields.
  """
  @fallback_to_any true
  @spec encode(Zoi.schema()) :: binary()
  def encode(schema)
end

defimpl Zoi.Describe.Encoder, for: Any do
  def encode(schema) do
    raise ArgumentError, "Describe.Encoder not implemented for schema: #{inspect(schema)}"
  end
end
