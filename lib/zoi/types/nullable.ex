defmodule Zoi.Types.Nullable do
  @moduledoc false

  def new(inner, opts \\ []) do
    Zoi.union([Zoi.null(error: inner.meta.error), inner], opts)
  end
end
