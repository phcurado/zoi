defmodule Zoi.Types.Map do
  use Zoi.Types.Base, fields: [:fields]

  def new(fields, opts \\ []) do
    opts = Keyword.merge(opts, fields: fields)
    struct!(__MODULE__, opts)
  end
end

defimpl Zoi.Type, for: Zoi.Types.Map do
  def parse(%Zoi.Types.Map{fields: fields}, input, opts) when is_map(input) do
    Enum.reduce(fields, {%{}, %{}}, fn {key, type}, {parsed, errors} ->
      case map_fetch(input, key) do
        :error ->
          if optional?(type) do
            # If the field is optional, we skip it and do not add it to parsed
            {parsed, errors}
          else
            {parsed, Map.put(errors, key, %Zoi.Error{message: "is required", key: key})}
          end

        {:ok, value} ->
          case Zoi.Type.parse(type, value, opts) do
            {:ok, val} ->
              {Map.put(parsed, key, val), errors}

            {:error, err} ->
              {parsed, Map.put(errors, key, err)}
          end
      end
    end)
    |> then(fn {parsed, errors} ->
      if errors == %{} do
        {:ok, parsed}
      else
        {:error, errors}
      end
    end)
  end

  def parse(_, _, _) do
    {:error, %Zoi.Error{message: "invalid map type"}}
  end

  defp map_fetch(map, key) do
    case Map.fetch(map, key) do
      :error ->
        Map.fetch(map, to_string(key))

      {:ok, _val} = result ->
        result
    end
  end

  defp optional?(%Zoi.Types.Optional{}), do: true
  defp optional?(_), do: false
end
