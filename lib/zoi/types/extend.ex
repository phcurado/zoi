defmodule Zoi.Types.Extend do
  @moduledoc false

  use Zoi.Type.Def, fields: [:schema1, :schema2]

  alias Zoi.Types.Object

  def new(%Object{} = schema1, %Object{} = schema2, _opts) do
    fields = Map.merge(schema1.fields, schema2.fields)
    strict = schema1.strict || schema2.strict
    coerce = schema1.coerce || schema2.coerce

    Zoi.Types.Object.new(fields, strict: strict, coerce: coerce)
  end

  def new(_schema1, _schema2, _opts) do
    raise ArgumentError, "must be an object"
  end
end
