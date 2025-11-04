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
        data: input,
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

      # Scope data/params to the nested field
      {data, params} =
        case {parent.data, parent.params} do
          {%{} = d, %{} = p} ->
            {Map.get(d, field) || default, Map.get(p, field_str) || %{}}

          {d, p} ->
            {d || default, p || %{}}
        end

      nested_errors =
        context.errors
        |> Enum.flat_map(fn
          %Zoi.Error{path: [^field | rest], issue: issue} ->
            case rest do
              # error attached to the object itself
              [] -> [base: issue]
              # error for a child key
              [k | _] -> [{k, issue}]
            end

          _ ->
            []
        end)

      [
        %Phoenix.HTML.Form{
          source: context,
          impl: __MODULE__,
          id: id,
          name: name,
          data: data,
          action: action,
          params: params,
          errors: nested_errors,
          options: opts
        }
      ]
    end

    @impl true
    def input_validations(_context, _form, _field), do: []

    @impl true
    def input_value(%{parsed: changes, input: data}, %{params: params}, field)
        when is_atom(field) or is_binary(field) do
      case changes do
        %{^field => value} ->
          value

        _ ->
          string = to_string(field)

          case params do
            %{^string => value} -> value
            %{} -> Map.get(data, field)
          end
      end
    end

    defp form_for_errors(_context, nil = _action), do: []
    defp form_for_errors(_context, :ignore = _action), do: []

    defp form_for_errors(%Zoi.Context{errors: errors}, _action) do
      errors
      |> Enum.flat_map(fn
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
