defmodule Zoi.Types.Number do
  @moduledoc false

  def new(opts \\ []) do
    # Number is a union type of Float and Integer
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)

    error = meta.error || "invalid number type"

    Zoi.union([Zoi.integer(error: error), Zoi.float(error: error)], opts)
  end
end
