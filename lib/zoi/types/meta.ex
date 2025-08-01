defmodule Zoi.Types.Meta do
  @moduledoc false

  @type t :: %__MODULE__{validations: [mfa()]}

  @struct_fields [validations: []]
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
