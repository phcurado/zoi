defmodule Zoi.Types.Map do
  @moduledoc false

  use Zoi.Type.Def, fields: [:key_type, :value_type]

  def new(key_type, value_type, opts) do
    apply_type(Keyword.merge(opts, key_type: key_type, value_type: value_type))
  end

  def new(opts) do
    new(Zoi.any(), Zoi.any(), opts)
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Map{} = schema, input, _opts) when is_map(input) do
      Enum.reduce(input, {input, []}, fn {key, value}, {input, errors} ->
        with {:ok, _parsed} <- Zoi.parse(schema.key_type, key),
             {:ok, _parsed} <- Zoi.parse(schema.value_type, value) do
          {input, errors}
        else
          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.add_path(&1, [key]))
            {input, Zoi.Errors.merge(errors, error)}
        end
      end)
      |> then(fn {parsed, errors} ->
        if errors == [] do
          {:ok, parsed}
        else
          {:error, errors}
        end
      end)
    end

    def parse(schema, _, _) do
      {:error, schema.meta.error || "invalid type: must be a map"}
    end
  end
end
