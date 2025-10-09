defmodule Zoi.JSONSchema do
  @moduledoc false

  def encode(schema) do
    schema
    |> encode_schema()
    |> add_draft()
  end

  defp add_draft(encoded_schema) do
    Map.put(encoded_schema, :"$schema", "https://json-schema.org/draft/2020-12/schema")
  end

  defp encode_schema(%Zoi.Types.String{}) do
    %{type: :string}
  end

  defp encode_schema(%Zoi.Types.Integer{}) do
    %{type: :integer}
  end
end
