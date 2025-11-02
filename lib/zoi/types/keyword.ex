defmodule Zoi.Types.Keyword do
  @moduledoc false

  use Zoi.Type.Def, fields: [:fields, :strict, :coerce]

  def new(fields, opts) when is_list(fields) or is_struct(fields) do
    opts =
      Keyword.merge(
        [error: "invalid type: must be a keyword list", strict: false, coerce: false],
        opts
      )

    apply_type(opts ++ [fields: fields])
  end

  def new(_fields, _opts) do
    raise ArgumentError, "keyword must receive a keyword list"
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Keyword{fields: fields} = type, input, opts)
        when is_list(fields) and is_list(input) do
      do_parse(type, input, opts, [], [])
      |> then(fn {parsed, errors, _path} ->
        if errors == [] do
          {:ok, parsed}
        else
          {:error, errors}
        end
      end)
    end

    def parse(%Zoi.Types.Keyword{fields: schema_type}, input, _opts) when is_list(input) do
      Enum.reduce(input, {[], [], []}, fn {key, value}, {parsed, errors, path} ->
        ctx = Zoi.Context.new(schema_type, value) |> Zoi.Context.add_path(path)

        Zoi.parse(schema_type, value, ctx: ctx)
        |> then(fn
          {:ok, val} ->
            {[{key, val} | parsed], errors, path}

          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.prepend_path(&1, path ++ [key]))
            {parsed, Zoi.Errors.merge(errors, error), path}
        end)
      end)
      |> then(fn {parsed, errors, _path} ->
        if errors == [] do
          {:ok, Enum.reverse(parsed)}
        else
          {:error, errors}
        end
      end)
    end

    def parse(schema, _, _) do
      {:error, schema.meta.error}
    end

    defp do_parse(
           %Zoi.Types.Keyword{fields: fields, strict: strict, coerce: coerce},
           input,
           opts,
           path,
           errs
         )
         when is_list(input) do
      unknown_fields_errors =
        if strict do
          unknown_fields(fields, input)
        else
          []
        end
        |> Enum.map(&Zoi.Error.prepend_path(&1, path))

      Enum.reduce(fields, {[], errs, path}, fn {key, type}, {parsed, errors, path} ->
        case keyword_fetch(input, key, coerce) do
          :error ->
            cond do
              optional?(type) ->
                # If the field is optional, we skip it and do not add it to parsed
                {parsed, errors, path}

              default?(type) ->
                # If the field has a default value, we add it to parsed
                {[{key, type.value} | parsed], errors, path}

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
                {[{key, val} | parsed], errors, path}

              {:error, err} ->
                error = Enum.map(err, &Zoi.Error.prepend_path(&1, path ++ [key]))
                {parsed, Zoi.Errors.merge(errors, error), path}

              {obj_parsed, obj_errors, _path} ->
                {[{key, obj_parsed} | parsed], Zoi.Errors.merge(errors, obj_errors), path}
            end
        end
      end)
      |> then(fn {parsed, errors, path} ->
        {Enum.reverse(parsed), Zoi.Errors.merge(errors, unknown_fields_errors), path}
      end)
    end

    ## Simple type parsing
    defp do_parse(type, value, _opts, path, _errors) do
      ctx = Zoi.Context.new(type, value) |> Zoi.Context.add_path(path)
      Zoi.parse(type, value, ctx: ctx)
    end

    defp optional?(type) do
      !type.meta.required
    end

    defp default?(%Zoi.Types.Default{}), do: true
    defp default?(_), do: false

    def unknown_fields(fields, input) do
      schema_keys = Keyword.keys(fields)

      input
      |> Enum.map(fn {k, _v} -> k end)
      |> Enum.reject(&(&1 in schema_keys))
      |> Enum.map(fn key ->
        Zoi.Error.exception(message: "unrecognized key: '#{key}'")
      end)
    end

    defp keyword_fetch(input_map, key, true = _coerce) do
      Enum.map(input_map, fn {k, v} ->
        {to_string(k), v}
      end)
      |> Enum.into(%{})
      |> Map.fetch(to_string(key))
    end

    defp keyword_fetch(input_map, key, _coerce) do
      Enum.into(input_map, %{})
      |> Map.fetch(key)
    end

    def type_spec(%Zoi.Types.Keyword{fields: fields}, opts) when is_list(fields) do
      fields
      |> Enum.map(fn {key, type} ->
        quote do
          {unquote(key), unquote(Zoi.Type.type_spec(type, opts))}
        end
      end)
      |> then(fn list ->
        if list == [] do
          quote(do: keyword())
        else
          list
        end
      end)
    end

    def type_spec(%Zoi.Types.Keyword{fields: schema}, opts) do
      quote do
        [{atom(), unquote(Zoi.Type.type_spec(schema, opts))}]
      end
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
