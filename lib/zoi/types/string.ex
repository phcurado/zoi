defmodule Zoi.Types.String do
  use Zoi.Types.Base
end

defimpl Zoi.Type, for: Zoi.Types.String do
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
      is_binary(input) ->
        {:ok, input}

      # TODO: coerce option

      true ->
        {:error, %Zoi.Error{message: "invalid string type"}}
    end
  end
end
