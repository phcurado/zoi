defmodule Zoi.Types.Object do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :strict, :coerce]

  def new(fields, opts) when is_map(fields) do
    apply_type(opts ++ [fields: fields])
  end

  def new(_fields, _opts) do
    raise ArgumentError, "object must receive a map"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{} = type, input, opts) when is_map(input) do
      do_parse(type, input, opts, [], [])
      |> then(fn {parsed, errors, _path} ->
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

    defp do_parse(
           %Zoi.Types.Object{fields: fields, strict: strict, coerce: coerce},
           input,
           opts,
           path,
           errs
         ) do
      coerce = Keyword.get(opts, :coerce, coerce)

      unknown_fields_errors =
        if strict do
          unknown_fields(fields, input)
        else
          []
        end
        |> Enum.map(&Zoi.Error.add_path(&1, path))

      Enum.reduce(fields, {%{}, errs, path}, fn {key, type}, {parsed, errors, path} ->
        case map_fetch(input, key, coerce) do
          :error ->
            cond do
              optional?(type) ->
                # If the field is optional, we skip it and do not add it to parsed
                {parsed, errors, path}

              default?(type) ->
                # If the field has a default value, we add it to parsed
                {Map.put(parsed, key, type.value), errors, path}

              true ->
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
                error = Enum.map(err, &Zoi.Error.add_path(&1, path ++ [key]))
                {parsed, Zoi.Errors.merge(errors, error), path}

              {obj_parsed, obj_errors, _path} ->
                {Map.put(parsed, key, obj_parsed), obj_errors, path}
            end
        end
      end)
      |> then(fn {parsed, errors, path} ->
        {parsed, Zoi.Errors.merge(errors, unknown_fields_errors), path}
      end)
    end

    ## Simple type parsing
    defp do_parse(type, value, _opts, path, _errors) do
      ctx = Zoi.Context.new(type, value) |> Zoi.Context.add_path(path)
      Zoi.parse(type, value, ctx: ctx)
    end

    defp optional?(%Zoi.Types.Optional{}), do: true
    defp optional?(_), do: false

    defp default?(%Zoi.Types.Default{}), do: true
    defp default?(_), do: false

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

    defp map_fetch(input_map, key, true = _coerce) do
      Enum.map(input_map, fn {k, v} ->
        {to_string(k), v}
      end)
      |> Enum.into(%{})
      |> Map.fetch(to_string(key))
    end

    defp map_fetch(input_map, key, _coerce) do
      Map.fetch(input_map, key)
    end
  end
end
