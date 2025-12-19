defprotocol Zoi.JSONSchema.Encoder do
  @moduledoc false

  @doc """
  Returns the JSON Schema representation for a type, including any constraints.
  Metadata and effect refinements are handled by `Zoi.JSONSchema`.
  """
  @fallback_to_any true
  @spec encode(Zoi.Type.t()) :: map()
  def encode(schema)
end

defimpl Zoi.JSONSchema.Encoder, for: Any do
  def encode(schema) do
    raise ArgumentError, "Encoding not implemented for schema: #{inspect(schema)}"
  end
end
