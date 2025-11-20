defmodule Zoi.Types.Extend do
  @moduledoc false

  def new(schema1, shema2, opts \\ [])

  def new(%Zoi.Types.Object{} = schema1, %Zoi.Types.Object{} = schema2, _opts) do
    fields = Keyword.merge(schema1.fields, schema2.fields)
    strict = schema1.strict || schema2.strict
    coerce = schema1.coerce || schema2.coerce
    empty_values = schema1.empty_values || schema2.empty_values

    Zoi.Types.Object.new(fields, strict: strict, coerce: coerce, empty_values: empty_values)
  end

  def new(%Zoi.Types.Object{} = schema1, schema2, _opts)
      when is_map(schema2) and not is_struct(schema2) do
    fields = Keyword.merge(schema1.fields, Map.to_list(schema2))
    strict = schema1.strict
    coerce = schema1.coerce
    empty_values = schema1.empty_values

    Zoi.Types.Object.new(fields, strict: strict, coerce: coerce, empty_values: empty_values)
  end

  def new(%Zoi.Types.Keyword{} = schema1, %Zoi.Types.Keyword{} = schema2, _opts) do
    fields = Keyword.merge(schema1.fields, schema2.fields)
    strict = schema1.strict || schema2.strict
    coerce = schema1.coerce || schema2.coerce
    empty_values = schema1.empty_values || schema2.empty_values

    Zoi.Types.Keyword.new(fields, strict: strict, coerce: coerce, empty_values: empty_values)
  end

  def new(%Zoi.Types.Keyword{} = schema1, schema2, _opts) when is_list(schema2) do
    fields = Keyword.merge(schema1.fields, schema2)
    strict = schema1.strict
    coerce = schema1.coerce
    empty_values = schema1.empty_values

    Zoi.Types.Keyword.new(fields, strict: strict, coerce: coerce, empty_values: empty_values)
  end

  def new(_schema1, _schema2, _opts) do
    raise ArgumentError, "must be an object"
  end
end
