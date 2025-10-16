defmodule Zoi.Inspect do
  @moduledoc false
  import Inspect.Algebra

  alias Zoi.Types.Meta

  def inspect_type(type, opts) do
    name = inspect_name(type)

    concat([
      "#Zoi.#{name}<",
      inspect_required(type),
      ">"
    ])
  end

  def inspect_name(type) do
    type.__struct__ |> Module.split() |> List.last() |> Macro.underscore()
  end

  def inspect_required(type) do
    if type.meta.required do
      concat([nest(line(), 2), "required"])
    else
      empty()
    end
  end
end
