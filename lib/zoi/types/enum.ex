defmodule Zoi.Types.Enum do
  @moduledoc false
  use Zoi.Type.Def, fields: [:values, :enum_type, coerce: false]

  def opts() do
    Zoi.Opts.meta_opts()
    |> Zoi.Opts.with_coerce()
  end

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
    def parse(%Zoi.Types.Enum{} = schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      Enum.find(schema.values, fn {key, value} ->
        if coerce do
          input == value or input == key
        else
          input == value
        end
      end)
      |> case do
        nil ->
          error(schema)

        {key, _value} ->
          {:ok, key}
      end
    end

    defp error(schema) do
      {:error, Zoi.Error.invalid_enum_value(schema.values, error: schema.meta.error)}
    end

  end

  defimpl Zoi.TypeSpec do
    def spec(%Zoi.Types.Enum{values: values}, _opts) do
      keys = Enum.map(values, fn {key, _value} -> key end)

      cond do
        Enum.all?(keys, &is_binary(&1)) ->
          quote(do: binary())

        Enum.any?(keys, &is_binary(&1)) ->
          quote(do: any())

        true ->
          keys
          |> Enum.reverse()
          |> Enum.reduce(&quote(do: unquote(&1) | unquote(&2)))
      end
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      symmetric_enum? = Enum.all?(type.values, fn {key, value} -> key == value end)

      values =
        if symmetric_enum? do
          Enum.map(type.values, fn {_key, value} -> value end)
        else
          type.values
        end

      Zoi.Inspect.build(type, opts, values: values)
    end
  end

  defimpl Zoi.JSONSchema.Encoder do
    def encode(schema) do
      %{type: :string, enum: Enum.map(schema.values, fn {_k, v} -> v end)}
    end
  end
end
