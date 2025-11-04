defmodule Zoi.Types.Nullable do
  @moduledoc false

  def new(inner, opts \\ []) do
    Zoi.union([Zoi.null(), inner], opts)
  end
end
