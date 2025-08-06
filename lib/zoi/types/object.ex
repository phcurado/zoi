defmodule Zoi.Types.Object do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :strict]

  def new(fields, opts \\ []) do
    apply_type(opts ++ [fields: fields])
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{fields: fields, strict: strict} = type, input, opts)
        when is_map(input) do
      do_parse(type, input, opts, [], [])
      |> then(fn {parsed, errors, _path} ->
        if errors == [] do
          {:ok, parsed}
        else
          {:error, errors}
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

    defp do_parse(%Zoi.Types.Object{fields: fields, strict: strict}, input, opts, path, errors) do
      Enum.reduce(fields, {%{}, errors, path}, fn {key, type}, {parsed, errors, path} ->
        case map_fetch(input, key) do
          :error ->
            if optional?(type) do
              # If the field is optional, we skip it and do not add it to parsed
              {parsed, errors, path}
            else
              {parsed,
               Zoi.Errors.add_error(
                 errors,
                 Zoi.Error.exception(message: "is required", path: path ++ [key])
               ), path}
            end

          {:ok, value} ->
            case do_parse(type, value, opts, path ++ [key], errors) do
              {:ok, val} ->
                {Map.put(parsed, key, val), errors, path}

              {:error, err} ->
                error = Enum.map(err, &Zoi.Error.add_path(&1, [key]))
                {parsed, Zoi.Errors.merge(errors, error), path}

              {obj_parsed, obj_errors, path} ->
                {Map.put(parsed, key, obj_parsed), Zoi.Errors.merge(errors, obj_errors), path}
            end
        end
      end)
    end

    ## Simple type parsing
    defp do_parse(type, value, _opts, _path, _errors), do: Zoi.parse(type, value)

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
