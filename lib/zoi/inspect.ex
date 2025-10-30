defmodule Zoi.Inspect do
  @moduledoc false
  import Inspect.Algebra

  def inspect_type(type, opts) do
    name = inspect_name(type)

    list = meta_list(type) ++ Map.get(opts, :extra_fields, [])

    container_doc("#Zoi.#{name}<", list, ">", %{limit: 5}, fn
      {:required, required}, _opts ->
        if required do
          concat("required: ", to_doc(required, opts))
        else
          empty()
        end

      {:description, description}, _opts ->
        if description do
          concat("description: ", to_doc(description, opts))
        else
          empty()
        end

      {key, {:doc_group, _, _} = doc}, _opts ->
        # tuple means it was already been converted to doc
        # this usually happens when parsing nested types
        concat("#{key}: ", doc)

      {key, value}, _opts ->
        concat("#{key}: ", to_doc(value, opts))
    end)
  end

  defp meta_list(type) do
    Enum.map([:required, :description], &{&1, Map.get(type.meta, &1)})
  end

  defp inspect_name(type) do
    type.__struct__ |> Module.split() |> List.last() |> Macro.underscore()
  end
end
