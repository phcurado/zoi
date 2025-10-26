defmodule Zoi.Types.Nullish do
  @moduledoc false

  def new(inner, opts \\ []) do
    Zoi.optional(Zoi.nullable(inner, opts))
  end
end
