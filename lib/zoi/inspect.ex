defmodule Zoi.Inspect do
  @moduledoc false

  import Inspect.Algebra

  @spec build(Zoi.schema(), Inspect.Opts.t(), keyword()) :: Inspect.Algebra.t()
  def build(type, inspect_opts, extra_fields \\ []) do
    name = inspect_name(type)

    list =
      meta_field_list(type) ++ type_common_fields(type) ++ extra_fields

    container_doc("#Zoi.#{name}<", list, ">", %Inspect.Opts{limit: 8}, fn
      {_key, nil}, _opts ->
        empty()

      {key, {:doc_group, _, _} = doc}, _opts ->
        concat("#{key}: ", doc)

      {key, value}, _opts ->
        concat("#{key}: ", to_doc(value, inspect_opts))
    end)
  end

  defp meta_field_list(type) do
    Enum.map([:required, :description], &{&1, Map.get(type.meta, &1)})
  end

  defp type_common_fields(type) do
    Enum.map([:coerce, :strict], &{&1, Map.get(type, &1)})
  end

  defp inspect_name(type) do
    modules = type.__struct__ |> Module.split()

    case modules do
      ["Zoi", "ISO", name] -> "ISO." <> Macro.underscore(name)
      list -> List.last(list) |> Macro.underscore()
    end
  end
end
