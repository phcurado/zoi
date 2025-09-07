defmodule Zoi.Types.Optional do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  alias Zoi.Types.Meta

  def new(inner, _opts) do
    %{inner | meta: %Meta{inner.meta | required: false}}
  end
end
