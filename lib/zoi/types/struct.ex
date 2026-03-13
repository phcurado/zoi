defmodule Zoi.Types.Struct do
  @moduledoc false

  use Zoi.Type.Def, fields: [:module, :fields, :unrecognized_keys, :coerce, empty_values: []]

  def opts() do
    Zoi.Opts.complex_type_opts()
  end

  def new(module, nil, opts) do
    opts =
      opts
      |> resolve_unrecognized_keys()
      |> Keyword.put_new(:coerce, false)

    apply_type(opts ++ [module: module, fields: nil])
  end

  def new(module, fields, opts) when is_map(fields) or is_list(fields) do
    fields =
      Enum.map(fields, fn {key, type} ->
        if type.meta.required == nil do
          {key, Zoi.required(type)}
        else
          {key, type}
        end
      end)

    keys = Enum.map(fields, fn {key, _type} -> key end)

    if Enum.any?(keys, &(!is_atom(&1))) do
      raise ArgumentError, "all keys in struct must be atoms"
    end

    opts =
      opts
      |> resolve_unrecognized_keys()
      |> Keyword.put_new(:coerce, false)

    apply_type(opts ++ [module: module, fields: fields])
  end

  def new(_module, _fields, _opts) do
    raise ArgumentError, "struct must receive a map or nil"
  end

  defp resolve_unrecognized_keys(opts) do
    opts =
      case {opts[:unrecognized_keys], opts[:strict]} do
        {nil, nil} -> Keyword.put(opts, :unrecognized_keys, :strip)
        {nil, true} -> opts |> Keyword.delete(:strict) |> Keyword.put(:unrecognized_keys, :error)
        {nil, false} -> opts |> Keyword.delete(:strict) |> Keyword.put(:unrecognized_keys, :strip)
        {_, _} -> Keyword.delete(opts, :strict)
      end

    case opts[:unrecognized_keys] do
      :preserve ->
        raise ArgumentError, "unrecognized_keys: :preserve is not supported for structs"

      {:preserve, _} ->
        raise ArgumentError, "unrecognized_keys: {:preserve, schema} is not supported for structs"

      _ ->
        :ok
    end

    opts
  end

  defimpl Zoi.Type do
    # When fields is nil, just validate the struct type without field validation
    def parse(%Zoi.Types.Struct{module: module, fields: nil}, %module{} = input, _opts) do
      {:ok, input}
    end

    def parse(%Zoi.Types.Struct{module: module} = struct, %module{} = input, opts) do
      input = Map.from_struct(input)

      Zoi.Types.KeyValue.parse(struct, input, opts)
      |> case do
        {:ok, map} -> {:ok, struct!(module, map)}
        error -> error
      end
    end

    def parse(%Zoi.Types.Struct{module: module, coerce: true} = struct, input, opts)
        when is_map(input) do
      Zoi.Types.KeyValue.parse(struct, input, opts)
      |> case do
        {:ok, map} -> {:ok, struct!(module, map)}
        error -> error
      end
    end

    def parse(schema, _, _) do
      {:error, Zoi.Error.invalid_type(:struct, error: schema.meta.error)}
    end
  end

  defimpl Zoi.TypeSpec do
    alias Zoi.Types.{Default, Meta}

    def spec(%Zoi.Types.Struct{module: module, fields: nil}, _opts) do
      quote(do: %unquote(module){})
    end

    def spec(%Zoi.Types.Struct{module: module, fields: fields}, opts) do
      fields
      |> Enum.map(fn {key, type} ->
        type_spec =
          type
          |> Zoi.TypeSpec.spec(opts)
          |> maybe_add_nil_to_typespec(type)

        quote do: {unquote(key), unquote(type_spec)}
      end)
      |> then(&quote(do: %unquote(module){unquote_splicing(&1)}))
    end

    defp maybe_add_nil_to_typespec(type_spec, type) do
      if nilable_field?(type) and not nilable_typespec?(type_spec) do
        quote(do: nil | unquote(type_spec))
      else
        type_spec
      end
    end

    defp nilable_field?(%Default{value: nil}), do: true
    defp nilable_field?(type), do: Meta.optional?(type.meta)

    defp nilable_typespec?(nil), do: true

    defp nilable_typespec?({:|, _, [left, right]}),
      do: nilable_typespec?(left) or nilable_typespec?(right)

    defp nilable_typespec?(_), do: false
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{fields: nil} = type, opts) do
      Zoi.Inspect.build(type, opts, module: type.module)
    end

    def inspect(type, opts) do
      fields_doc =
        container_doc("%{", type.fields, "}", %Inspect.Opts{limit: 10}, fn
          {key, schema}, _opts -> concat("#{key}: ", Inspect.inspect(schema, opts))
        end)

      Zoi.Inspect.build(type, opts, fields: fields_doc, module: type.module)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(%{module: module}) do
      "struct of type `#{inspect(module)}`"
    end
  end
end
