defmodule Zoi.Types.Object do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :strict]

  def new(fields, opts \\ []) do
    apply_type(opts ++ [fields: fields])
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{fields: fields, strict: strict}, input, _opts)
        when is_map(input) do
      unknwon_fields_errors =
        if strict do
          unknown_fields(fields, input)
        else
          []
        end

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
            case Zoi.parse(type, value) do
              {:ok, val} ->
                {Map.put(parsed, key, val), errors}

              {:error, err} ->
                error = Enum.map(err, &Zoi.Error.add_path(&1, [key]))
                {parsed, Zoi.Errors.merge(errors, error)}
            end
        end
      end)
      |> then(fn {parsed, errors} ->
        if errors == [] and unknwon_fields_errors == [] do
          {:ok, parsed}
        else
          {:error, Zoi.Errors.merge(errors, unknwon_fields_errors)}
        end
      end)
    end

    def parse(_, _, _) do
      {:error, "invalid object type"}
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

    def unknown_fields(fields, input) do
      schema_keys =
        fields
        |> Map.keys()
        |> Enum.map(&to_string/1)

      input
      |> Map.keys()
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(&1 in schema_keys))
      |> Enum.map(fn key ->
        Zoi.Error.exception(message: "unrecognized key: '#{key}'")
      end)
    end
  end
end
