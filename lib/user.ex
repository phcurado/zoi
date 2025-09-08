defmodule User do
  import Zoi.Struct, only: [structure: 1]

  structure(%{
    name: Zoi.string() |> Zoi.required(),
    age: Zoi.optional(Zoi.integer()),
    address: Zoi.default(Zoi.string(), "Unknown")
  })
end
