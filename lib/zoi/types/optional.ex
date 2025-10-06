defmodule Zoi.Types.Optional do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  alias Zoi.Types.Meta

  def new(inner, _opts) do
    meta = %Meta{} = inner.meta
    %{inner | meta: %Meta{meta | required: false}}
  end
end
