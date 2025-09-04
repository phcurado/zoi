defmodule Zoi.Types.StringBoolean do
  @moduledoc false

  use Zoi.Type.Def, fields: [:case, :truthy, :falsy]

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_boolean(input) do
      {:ok, input}
    end

    def parse(schema, input, _opts) when is_binary(input) do
      truthy = schema.truthy || ["true", "1", "yes", "on", "y", "enabled"]
      falsy = schema.falsy || ["false", "0", "no", "off", "n", "disabled"]
      case_sensitive = schema.case || "insensitive"

      input = modify_input_case(input, case_sensitive)

      cond do
        input in truthy ->
          {:ok, true}

        input in falsy ->
          {:ok, false}

        true ->
          error(schema)
      end
    end

    def parse(schema, _input, _opts) do
      error(schema)
    end

    defp modify_input_case(input, "sensitive"), do: input
    defp modify_input_case(input, "insensitive"), do: String.downcase(input)

    defp error(schema) do
      {:error, schema.meta.error || "invalid type: must be a string boolean"}
    end

    def type_spec(_schema, _opts) do
      quote(do: boolean())
    end
  end
end
