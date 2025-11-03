defmodule Zoi.Types.StringBoolean do
  @moduledoc false

  use Zoi.Type.Def, fields: [:case, :truthy, :falsy]

  def new(opts \\ []) do
    truthy = ["true", "1", "yes", "on", "y", "enabled"]
    falsy = ["false", "0", "no", "off", "n", "disabled"]

    opts =
      Keyword.merge(
        [
          case: "insensitive",
          truthy: truthy,
          falsy: falsy
        ],
        opts
      )

    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(_schema, input, _opts) when is_boolean(input) do
      {:ok, input}
    end

    def parse(schema, input, _opts) when is_binary(input) do
      input = modify_input_case(input, schema.case)

      cond do
        input in schema.truthy ->
          {:ok, true}

        input in schema.falsy ->
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
      {:error, Zoi.Error.invalid_type("string boolean", custom_message: schema.meta.error)}
    end

    def type_spec(_schema, _opts) do
      quote(do: boolean())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
