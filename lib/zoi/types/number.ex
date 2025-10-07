defmodule Zoi.Types.Number do
  @moduledoc false

  def new(opts \\ []) do
    # Number is a union type of Float and Integer
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)

    error = meta.error || "invalid type: must be a number"

    opts = Keyword.merge(opts, error: error, example: meta.example)

    Zoi.union([Zoi.integer(), Zoi.float()], opts)
  end
end
