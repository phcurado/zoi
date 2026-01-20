defmodule Zoi.Types.JSON do
  @moduledoc false

  def new(opts) do
    Zoi.union(
      [
        Zoi.string(),
        Zoi.null(),
        Zoi.number(),
        Zoi.boolean(),
        Zoi.array(Zoi.lazy({Zoi.Types.JSON, :new, [opts]})),
        Zoi.map(Zoi.string(), Zoi.lazy({Zoi.Types.JSON, :new, [opts]}), [])
      ],
      opts
    )
  end
end
