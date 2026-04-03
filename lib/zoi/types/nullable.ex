defmodule Zoi.Types.Nullable do
  @moduledoc false

  alias Zoi.Types.Meta

  def new(inner, opts \\ []) do
    inner_opts = Meta.propagate_opts(inner.meta)
    Zoi.union([Zoi.null(), inner], Keyword.merge(inner_opts, opts))
  end
end
