defmodule Zoi.Struct do
  @moduledoc """
  This module provides a macro to define structs with enforced keys and default values.
  """

  alias Zoi.Types.Meta

  @doc """
  Defines a struct with enforced keys and default values.

  ## Examples

      defmodule User do
        Zoi.structure(%{name: Zoi.string(), age: Zoi.optional(Zoi.integer()), address: Zoi.default(Zoi.string(), "Unknown")})
      end

  This will create the `User` struct as follows:

      defmodule User do
        @enforce_keys [:name, :address]
        @type t :: %User{name: binary(), age: integer() | nil, address: binary()}
        defstruct name: nil, age: nil, address: "Unknown"
      end
  """
  defmacro structure(fields) do
    quote bind_quoted: [fields: fields] do
      {zoi_object, enforce_keys, defaults} = Zoi.Struct.__fields__(fields)
      type = Zoi.type_spec(zoi_object)

      @type t :: unquote(type)
      @enforce_keys enforce_keys
      defstruct defaults
    end
  end

  @doc false
  def __fields__(fields) do
    keyword = Zoi.keyword(Map.to_list(fields))

    {enforced_keys, defaults} = build_struct(keyword.fields)

    {keyword, enforced_keys, defaults}
  end

  defp build_struct(fields) do
    Enum.reduce(fields, {[], []}, fn
      {key, %Zoi.Types.Default{value: default}}, {enforce_keys, defaults} ->
        {enforce_keys, [{key, default} | defaults]}

      {key, type}, {enforce_keys, defaults} ->
        if Meta.optional?(type.meta) do
          {enforce_keys, [{key, nil} | defaults]}
        else
          {[key | enforce_keys], [{key, nil} | defaults]}
        end
    end)
  end
end
