if Code.ensure_loaded?(Phoenix.HTML) do
  defimpl Phoenix.HTML.FormData, for: Zoi.Context do
    @impl true
    def to_form(%Zoi.Context{} = context, opts) do
      %{input: input} = context

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
        data: input || %{},
        params: input || %{},
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

      if is_list(data) or is_list(params) do
        items_data = list_or_empty_maps(data)
        items_params = list_or_empty_maps(params)

        max_len = max(length(items_data), length(items_params))

        Enum.map(0..(max_len - 1), fn idx ->
          item_data = Enum.at(items_data, idx) || %{}
          item_params = Enum.at(items_params, idx) || %{}

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
        # OBJECT: single form
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

    defp scope_nested(data, params, field_atom, field_string, default) do
      cond do
        is_map(data) and is_map(params) ->
          {Map.get(data, field_atom, default), Map.get(params, field_string, %{})}

        true ->
          {data || default, params || %{}}
      end
    end

    defp list_or_empty_maps(list) when is_list(list), do: list
    defp list_or_empty_maps(_), do: []

    defp ensure_map(%{} = m, _fallback), do: m

    defp ensure_map(m, fallback) do
      if is_list(m) and Keyword.keyword?(m) do
        Map.new(m)
      else
        fallback
      end
    end

    # Errors directly under the nested object: [:field] and [:field, k]
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

    # Errors for a collection item: [:field, idx] and [:field, idx, k]
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

        is_map(data) and Map.has_key?(data, field) ->
          Map.get(data, field)

        true ->
          nil
      end
    end

    defp form_for_errors(_context, nil), do: []
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
  end
end
