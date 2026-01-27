defmodule Zoi.Types.Extend do
  @moduledoc false

  def new(schema1, shema2, opts \\ [])

  def new(
        %Zoi.Types.Map{fields: fields1} = schema1,
        %Zoi.Types.Map{fields: fields2},
        _opts
      )
      when is_list(fields1) and is_list(fields2) do
    fields = Keyword.merge(fields1, fields2)

    Zoi.Types.Map.new(Map.new(fields),
      unrecognized_keys: schema1.unrecognized_keys,
      coerce: schema1.coerce,
      empty_values: schema1.empty_values
    )
  end

  def new(%Zoi.Types.Map{fields: fields1} = schema1, schema2, _opts)
      when is_list(fields1) and is_map(schema2) and not is_struct(schema2) do
    fields = Keyword.merge(fields1, Map.to_list(schema2))

    Zoi.Types.Map.new(Map.new(fields),
      unrecognized_keys: schema1.unrecognized_keys,
      coerce: schema1.coerce,
      empty_values: schema1.empty_values
    )
  end

  def new(%Zoi.Types.Keyword{} = schema1, %Zoi.Types.Keyword{} = schema2, _opts) do
    fields = Keyword.merge(schema1.fields, schema2.fields)

    Zoi.Types.Keyword.new(fields,
      unrecognized_keys: schema1.unrecognized_keys,
      coerce: schema1.coerce,
      empty_values: schema1.empty_values
    )
  end

  def new(%Zoi.Types.Keyword{} = schema1, schema2, _opts) when is_list(schema2) do
    fields = Keyword.merge(schema1.fields, schema2)

    Zoi.Types.Keyword.new(fields,
      unrecognized_keys: schema1.unrecognized_keys,
      coerce: schema1.coerce,
      empty_values: schema1.empty_values
    )
  end

  def new(_schema1, _schema2, _opts) do
    raise ArgumentError, "must be an object or keyword"
  end
end
