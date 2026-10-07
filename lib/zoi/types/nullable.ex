defmodule Zoi.Types.Nullable do
  @moduledoc false

  alias Zoi.Types.Meta

  def new(inner, opts \\ []) do
    inner_opts = Meta.propagate_opts(inner.meta)
    Zoi.Types.Union.new([Zoi.Types.Null.new(), inner], Keyword.merge(inner_opts, opts))
  end
end
