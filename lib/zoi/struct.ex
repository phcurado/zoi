defmodule Zoi.Struct do
  @moduledoc """
  A helper module to define and validate structs using Zoi schemas.
  This module provides functions to extract `@enforce_keys` and struct fields from a Zoi struct schema.
  It is particularly useful when you want to create Elixir structs that align with Zoi schemas.
  ## Examples
      defmodule MyApp.SomeModule do
        @schema Zoi.struct(__MODULE__, %{
          name: Zoi.string() |> Zoi.required(),
          age: Zoi.integer() |> Zoi.default(0),
          email: Zoi.string()
        })

        @enforce_keys Zoi.Struct.enforce_keys(schema) # [:name]
        defstruct Zoi.Struct.struct_fields(schema) # [:name, {:age, 0}, :email]
      end
  """

  alias Zoi.Types.Meta

  @doc """
  Returns a list of keys that are required for the struct based on the schema.
  This is useful for defining `@enforce_keys` in Elixir structs.
  """
  @spec enforce_keys(Zoi.Types.Struct.t()) :: [atom()]
  def enforce_keys(%Zoi.Types.Struct{fields: fields}) do
    Enum.reduce(fields, [], fn {key, type}, acc ->
      if Meta.required?(type.meta) do
        [key | acc]
      else
        acc
      end
    end)
  end

  @doc """
  Returns a list of fields for the struct, where fields with default values are represented as tuples
  of the form `{key, default_value}`.
  This is useful for defining the fields of an Elixir struct.
  """
  @spec struct_fields(Zoi.Types.Struct.t()) :: [atom() | {atom(), Zoi.input()}]
  def struct_fields(%Zoi.Types.Struct{fields: fields}) do
    Enum.map(fields, fn
      {key, %Zoi.Types.Default{value: value}} -> {key, value}
      {key, _type} -> key
    end)
  end
end
