defmodule Zoi.Types.Array do
  @moduledoc false

  use Zoi.Type.Def, fields: [:inner]

  def new(inner, opts) do
    opts = Keyword.merge([error: "invalid type: must be an array"], opts)
    apply_type(opts ++ [inner: inner])
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Array{inner: inner}, inputs, _opts) when is_list(inputs) do
      inputs
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {input, index}, {parsed, errors} ->
        ctx = Zoi.Context.new(inner, input) |> Zoi.Context.add_path(index)

        case Zoi.parse(inner, input, ctx: ctx) do
          {:ok, value} ->
            {[value | parsed], errors}

          {:error, err} ->
            error = Enum.map(err, &Zoi.Error.add_path(&1, [index]))
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

    def parse(schema, _, _) do
      {:error, schema.meta.error}
    end

    def type_spec(%Zoi.Types.Array{inner: inner}, opts) do
      inner_spec = Zoi.Type.type_spec(inner, opts)

      quote do
        [unquote(inner_spec)]
      end
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.inspect_type(type, opts)
    end
  end
end
