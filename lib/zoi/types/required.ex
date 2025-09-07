defmodule Zoi.Types.Required do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  alias Zoi.Types.Meta

  def new(inner, _opts) do
    %{inner | meta: %Meta{inner.meta | required: true}}
  end
end
