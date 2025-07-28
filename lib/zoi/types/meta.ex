defmodule Zoi.Types.Meta do
  @moduledoc """
  Base module for Zoi types. It adds common functionality for defining types in Zoi.
  Every type in `Zoi` is a struct that includes some default fields. The type module should implement the `new/1` function to create a new instance of the type.
  You can then implement the `Zoi.Type` protocol for your type to define how it should parse and validate input. Check the `Zoi.Types.String` module for an example
  of how to use this base module.
  """

  @type t :: %__MODULE__{validations: [mfa()], coerce: boolean()}

  @struct_fields [validations: [], coerce: false]
  @struct_keys Keyword.keys(@struct_fields)

  defstruct @struct_fields

  @spec create_meta(keyword()) :: {t(), keyword()}
  def create_meta(opts) do
    {meta_opts, rest_opts} = split_keyword(opts)
    {struct!(__MODULE__, meta_opts), rest_opts}
  end

  defp split_keyword(opts) when is_list(opts) do
    Enum.reduce(opts, {[], []}, fn {k, v}, {meta_opts, rest_opts} ->
      if k in @struct_keys do
        {Keyword.put(meta_opts, k, v), rest_opts}
      else
        {meta_opts, Keyword.put(rest_opts, k, v)}
      end
    end)
  end
end
