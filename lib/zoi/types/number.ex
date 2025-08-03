defmodule Zoi.Types.Number do
  @moduledoc false

  def new(opts \\ []) do
    # Number is a union type of Float and Integer
    Zoi.union([Zoi.integer(), Zoi.float()], opts)
  end
end
