defmodule Zoi.Types.JSON do
  @moduledoc false

  def new(opts) do
    Zoi.union(
      [
        Zoi.string(),
        Zoi.null(),
        Zoi.number(),
        Zoi.boolean(),
        Zoi.array(Zoi.lazy(fn -> Zoi.Types.JSON.new(opts) end)),
        Zoi.map(Zoi.string(), Zoi.lazy(fn -> Zoi.Types.JSON.new(opts) end))
      ],
      opts
    )
  end
end
