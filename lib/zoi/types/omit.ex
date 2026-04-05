defmodule Zoi.Types.Omit do
  @moduledoc false

  def new(%Zoi.Types.Map{fields: fields} = schema, keys) when is_list(fields) and is_list(keys) do
    %{schema | fields: Keyword.drop(fields, keys)}
  end

  def new(%Zoi.Types.Keyword{fields: fields} = schema, keys) when is_list(keys) do
    %{schema | fields: Keyword.drop(fields, keys)}
  end

  def new(_schema, _keys) do
    raise ArgumentError, "must be an object or keyword"
  end
end
