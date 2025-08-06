defmodule Zoi.Types.Enum do
  @moduledoc false
  use Zoi.Type.Def, fields: [:values, :enum_type]

  def new(values, opts \\ []) when is_list(values) do
    type = verify_type(values)

    mapping =
      Enum.map(values, fn
        {key, value} ->
          {key, value}

        value ->
          {value, value}
      end)

    apply_type(opts ++ [values: mapping, enum_type: type])
  end

  defp verify_type([{key, value} | _rest]) when is_atom(key) and is_binary(value) do
    :atom_binary
  end

  defp verify_type([{key, value} | _rest]) when is_atom(key) and is_integer(value) do
    :atom_integer
  end

  defp verify_type([value | _rest]) when is_atom(value) do
    :atom
  end

  defp verify_type([value | _rest]) when is_binary(value) do
    :binary
  end

  defp verify_type([value | _rest]) when is_integer(value) do
    :integer
  end

  defp verify_type(_values) do
    raise ArgumentError, "Invalid enum values"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Enum{} = schema, input, _opts) do
      case parse_enum(schema, input) do
        {:error, _reason} = error ->
          error

        nil ->
          error(schema)

        {key, _value} ->
          {:ok, key}
      end
    end

    defp parse_enum(schema, input) do
      cond do
        schema.enum_type in [:atom_binary, :binary] and is_binary(input) ->
          compare_input(schema.values, input)

        schema.enum_type in [:atom_integer, :integer] and is_integer(input) ->
          compare_input(schema.values, input)

        schema.enum_type == :atom and is_atom(input) ->
          compare_input(schema.values, input)

        true ->
          error(schema)
      end
    end

    defp compare_input(values, input) do
      Enum.find(values, fn {_key, value} -> input == value end)
    end

    defp error(schema) do
      options = stringify_enum(schema.values)

      error =
        schema.meta.error || "invalid option, must be one of: #{options}"

      {:error, error}
    end

    defp stringify_enum(values) do
      Enum.map_join(values, ", ", fn
        {_key, value} ->
          value

        value ->
          value
      end)
    end
  end
end
