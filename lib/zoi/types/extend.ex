defmodule Zoi.Types.Extend do
  @moduledoc false

  use Zoi.Type.Def, fields: [:schema1, :schema2]

  def new(%Zoi.Types.Object{} = schema1, %Zoi.Types.Object{} = schema2, _opts) do
    fields = Map.merge(schema1.fields, schema2.fields)
    strict = schema1.strict || schema2.strict
    coerce = schema1.coerce || schema2.coerce

    Zoi.Types.Object.new(fields, strict: strict, coerce: coerce)
  end

  def new(%Zoi.Types.Keyword{} = schema1, %Zoi.Types.Keyword{} = schema2, _opts) do
    fields = Keyword.merge(schema1.fields, schema2.fields)
    strict = schema1.strict || schema2.strict
    coerce = schema1.coerce || schema2.coerce

    Zoi.Types.Keyword.new(fields, strict: strict, coerce: coerce)
  end

  def new(_schema1, _schema2, _opts) do
    raise ArgumentError, "must be an object"
  end
end
