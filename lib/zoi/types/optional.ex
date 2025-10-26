defmodule Zoi.Types.Optional do
  @moduledoc false

  use Zoi.Type.Def

  alias Zoi.Types.Meta

  def new(inner) do
    meta = %Meta{} = inner.meta
    %{inner | meta: %Meta{meta | required: false}}
  end
end
