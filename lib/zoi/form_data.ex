if Code.ensure_loaded?(Phoenix.HTML) do
  defimpl Phoenix.HTML.FormData, for: Zoi.Context do
    @impl true
    def to_form(%Zoi.Context{} = context, opts) do
      %{input: input, parsed: parsed} = context

      params = input || %{}

      {name, context, opts} = name_params_and_opts(context, opts)
      {action, opts} = Keyword.pop(opts, :action, nil)
      id = Keyword.get(opts, :id) || name

      unless is_binary(id) or is_nil(id) do
        raise ArgumentError, ":id option in form_for must be a binary/string, got: #{inspect(id)}"
      end

      %Phoenix.HTML.Form{
        source: context,
        impl: __MODULE__,
        id: id,
        action: action,
        name: name,
        errors: form_for_errors(context, action),
        data: parsed || input || %{},
        params: params,
        options: opts
      }
    end

    defp name_params_and_opts(context, opts) do
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {nil, context, opts}
        {name, opts} -> {to_string(name), context, opts}
      end
    end

    @impl true
    def to_form(%Zoi.Context{} = context, %Phoenix.HTML.Form{} = parent, field, opts) do
      {default, opts} = Keyword.pop(opts, :default, %{})
      {name_override, opts} = Keyword.pop(opts, :as)
      {action, opts} = Keyword.pop(opts, :action, parent.action)

      field_str = to_string(field)

      name =
        cond do
          is_binary(name_override) -> name_override
          parent.name -> "#{parent.name}[#{field_str}]"
          true -> field_str
        end

      id = Keyword.get(opts, :id) || name

      {data, params} =
        scope_nested(parent.data, parent.params, field, field_str, default)

      # Use schema to determine if this is an array field, not the data
      if array_field?(context.schema, field) do
        items_data = to_indexed_map(data)
        items_params = to_indexed_map(params)

        indices =
          (Map.keys(items_data) ++ Map.keys(items_params))
          |> Enum.uniq()
          |> Enum.sort()

        Enum.map(indices, fn idx ->
          item_data = Map.get(items_data, idx, %{})
          item_params = Map.get(items_params, idx, %{})

          item_name = "#{name}[#{idx}]"
          item_id = "#{id}[#{idx}]"

          %Phoenix.HTML.Form{
            source: context,
            impl: __MODULE__,
            id: item_id,
            name: item_name,
            data: item_data,
            params: item_params,
            action: action,
            errors: nested_collection_errors(context.errors, field, idx),
            options: opts
          }
        end)
      else
        [
          %Phoenix.HTML.Form{
            source: context,
            impl: __MODULE__,
            id: id,
            name: name,
            data: ensure_map(data, default),
            params: ensure_map(params, %{}),
            action: action,
            errors: nested_object_errors(context.errors, field),
            options: opts
          }
        ]
      end
    end

    # Extract nested data and params for a specific field
    # Tries both atom and string keys for maximum compatibility
    defp scope_nested(data, params, field_atom, field_string, default) do
      if is_map(data) and is_map(params) do
        data_value = Map.get(data, field_atom, default)
        params_value = Map.get(params, field_string) || Map.get(params, field_atom, %{})
        {data_value, params_value}
      else
        {data || default, params || %{}}
      end
    end

    defp to_indexed_map(list) when is_list(list) do
      list
      |> Enum.with_index()
      |> Map.new(fn {value, index} -> {index, value} end)
    end

    defp to_indexed_map(%{} = map) when map_size(map) == 0, do: %{}

    defp to_indexed_map(%{} = map) do
      if Enum.all?(map, fn {key, _} -> is_integer(key) end) do
        map
      else
        %{0 => map}
      end
    end

    defp to_indexed_map(_), do: %{}

    defp ensure_map(%{} = m, _fallback), do: m

    defp ensure_map(m, fallback) do
      if is_list(m) and Keyword.keyword?(m) do
        Map.new(m)
      else
        fallback
      end
    end

    defp nested_object_errors(errors, field) do
      Enum.flat_map(errors, fn
        %Zoi.Error{path: [^field], issue: issue} ->
          [base: issue]

        %Zoi.Error{path: [^field, k], issue: issue} when is_atom(k) or is_binary(k) ->
          [{k, issue}]

        _ ->
          []
      end)
    end

    defp nested_collection_errors(errors, field, idx) do
      Enum.flat_map(errors, fn
        %Zoi.Error{path: [^field, ^idx], issue: issue} ->
          [base: issue]

        %Zoi.Error{path: [^field, ^idx, k], issue: issue} when is_atom(k) or is_binary(k) ->
          [{k, issue}]

        _ ->
          []
      end)
    end

    @impl true
    def input_validations(_context, _form, _field), do: []

    @impl true
    def input_value(%{parsed: parsed, input: data}, %{params: params}, field)
        when is_atom(field) or is_binary(field) do
      key = to_string(field)

      cond do
        is_map(params) and Map.has_key?(params, key) ->
          Map.get(params, key)

        is_map(parsed) and Map.has_key?(parsed, field) ->
          Map.get(parsed, field)

        is_map(parsed) and Map.has_key?(parsed, key) ->
          Map.get(parsed, key)

        is_map(data) and Map.has_key?(data, field) ->
          Map.get(data, field)

        is_map(data) and Map.has_key?(data, key) ->
          Map.get(data, key)

        true ->
          nil
      end
    end

    defp form_for_errors(_context, :ignore), do: []

    defp form_for_errors(%Zoi.Context{errors: errors}, _action) do
      Enum.flat_map(errors, fn
        %Zoi.Error{path: [], issue: issue} ->
          [base: issue]

        %Zoi.Error{path: [field], issue: issue} when is_atom(field) or is_binary(field) ->
          [{field, issue}]

        _ ->
          []
      end)
    end

    # Determine if a field in the object schema is an array type
    # This is crucial for deciding whether to create multiple forms (array) or single form (object)
    defp array_field?(%Zoi.Types.Map{fields: fields}, field) when is_atom(field) do
      case get_field_schema(fields, field) do
        %Zoi.Types.Array{} -> true
        %Zoi.Types.Default{inner: inner} -> array_field_inner?(inner)
        _ -> false
      end
    end

    defp array_field?(_, _), do: false

    # Get field schema from fields (keyword list structure)
    # Note: Map fields are always stored as a list after construction
    defp get_field_schema(fields, field) when is_list(fields), do: Keyword.get(fields, field)

    # Recursively check if inner type is an array (for wrapped types like Default)
    defp array_field_inner?(%Zoi.Types.Array{}), do: true
    defp array_field_inner?(%Zoi.Types.Default{inner: inner}), do: array_field_inner?(inner)
    defp array_field_inner?(_), do: false
  end
end
