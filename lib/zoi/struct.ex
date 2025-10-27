defmodule Zoi.Struct do
  @moduledoc """
  A helper module to define and validate structs using Zoi schemas.
  This module provides functions to extract `@enforce_keys` and struct fields from a Zoi struct schema.
  It is particularly useful when you want to create Elixir structs that align with Zoi schemas.

  ## Examples
      defmodule MyApp.SomeModule do
        @schema Zoi.struct(__MODULE__, %{
                  name: Zoi.string() |> Zoi.nullable(),
                  age: Zoi.integer() |> Zoi.default(0) |> Zoi.optional(),
                  email: Zoi.string()
                })

        @type t :: unquote(Zoi.type_spec(@schema))
        @enforce_keys Zoi.Struct.enforce_keys(@schema) # [:name, :email]
        defstruct Zoi.Struct.struct_fields(@schema) # [:name, :email, {:age, 0}]
      end

  As shown in the example above, you can define a Zoi schema which will be used to generate a struct definition and especification.
  By default, `Zoi.struct/3` makes all fields required unless they are marked as optional, and you can leverage the schema definition to
  automatically generate the struct fields, type and enforce keys.

  The example above is the same as the following definition:

      defmodule MyApp.SomeModule do
        @type t :: %MyApp.SomeModule{
                name: binary() | nil,
                age: integer(),
                email: binary()
              }
        @enforce_keys [:name, :email]
        defstruct [:name, :email, age: 0]
      end

  The advantage of using `Zoi.struct/3` is that you can leverage Zoi's schema capabilities to define complex types, default values, validations, etc, and have those reflected in your Elixir struct definitions automatically.
  """
  alias Zoi.Types.Meta

  @doc """
  Returns a list of keys that are required for the struct based on the schema.
  This is useful for defining `@enforce_keys` in Elixir structs.
  """
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
  def struct_fields(%Zoi.Types.Struct{fields: fields}) do
    Enum.map(fields, fn
      {key, %Zoi.Types.Default{value: value}} -> {key, value}
      {key, _type} -> key
    end)
    |> Enum.sort_by(fn
      {_, _} -> 1
      _ -> 0
    end)
  end
end
