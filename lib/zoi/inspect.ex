defmodule Zoi.Inspect do
  @moduledoc false

  import Inspect.Algebra

  def inspect_type(type, opts) do
    name = inspect_name(type)

    list = meta_field_list(type) ++ type_common_fields(type) ++ Map.get(opts, :extra_fields, [])

    container_doc("#Zoi.#{name}<", list, ">", %Inspect.Opts{limit: 8}, fn
      {key, {:doc_group, _, _} = doc}, _opts ->
        # tuple means it was already been converted to doc
        # this usually happens when parsing nested types
        concat("#{key}: ", doc)

      {key, value}, _opts ->
        if value == nil do
          empty()
        else
          concat("#{key}: ", to_doc(value, opts))
        end
    end)
  end

  defp meta_field_list(nil), do: []

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
