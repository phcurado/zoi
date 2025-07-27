defmodule Zoi.Types.Integer do
  use Zoi.Types.Base
end

defimpl Zoi.Type, for: Zoi.Types.Integer do
  alias Zoi.Validations

  def parse(schema, input, opts) do
    do_parse(input, opts)
    |> then(fn
      {:ok, value} ->
        Validations.run_validations(schema, value)

      {:error, _reason} = error ->
        error
    end)
  end

  defp do_parse(input, _opts) do
    cond do
      is_integer(input) ->
        {:ok, input}

      # TODO: coerce option

      true ->
        {:error, %Zoi.Error{message: "invalid integer type"}}
    end
  end
end
