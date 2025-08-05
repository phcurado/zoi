defmodule Zoi.Types.Object do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields]

  def new(fields, opts \\ []) do
    apply_type(opts ++ [fields: fields])
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{fields: fields}, input, opts) when is_map(input) do
      Enum.reduce(fields, {%{}, []}, fn {key, type}, {parsed, errors} ->
        case map_fetch(input, key) do
          :error ->
            if optional?(type) do
              # If the field is optional, we skip it and do not add it to parsed
              {parsed, errors}
            else
              {parsed,
               Zoi.Errors.add_error(
                 errors,
                 Zoi.Error.exception(message: "is required", path: [key])
               )}
            end

          {:ok, value} ->
            case Zoi.parse(type, value, opts) do
              {:ok, val} ->
                {Map.put(parsed, key, val), errors}

              {:error, err} ->
                error =
                  Enum.map(err, fn error ->
                    Zoi.Error.add_path(error, [key])
                  end)

                {parsed, Zoi.Errors.merge(errors, error)}
            end
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

    def parse(_, _, _) do
      {:error, Zoi.Errors.add_error("invalid object type")}
    end

    defp map_fetch(map, key) do
      case Map.fetch(map, key) do
        :error ->
          Map.fetch(map, to_string(key))

        {:ok, _val} = result ->
          result
      end
    end

    defp optional?(%Zoi.Types.Optional{}), do: true
    defp optional?(_), do: false
  end
end
