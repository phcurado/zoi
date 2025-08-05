defmodule Zoi.Types.Array do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  def new(inner, opts \\ []) do
    apply_type(opts ++ [inner: inner])
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Array{inner: inner}, inputs, _opts) when is_list(inputs) do
      inputs
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {input, index}, {parsed, errors} ->
        case Zoi.parse(inner, input) do
          {:ok, value} ->
            {[value | parsed], errors}

          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.append_path(&1, [index]))
            {parsed, Zoi.Errors.merge(errors, error)}
        end
      end)
      |> then(fn {parsed, errors} ->
        if errors == [] do
          {:ok, Enum.reverse(parsed)}
        else
          {:error, errors}
        end
      end)
    end

    def parse(_, _, _) do
      {:error, "invalid array type"}
    end
  end
end
