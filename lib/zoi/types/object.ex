defmodule Zoi.Types.Object do
  @type map_field :: %{binary() => Zoi.Type.t()}
  @type fields :: [map_field]
  @type t :: %__MODULE__{fields: fields, meta: Zoi.Types.Base.t()}

  defstruct [:fields, :meta]

  @spec new(fields :: fields, opts :: keyword()) :: t()
  def new(fields, opts \\ []) do
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)
    opts = Keyword.merge(opts, fields: fields, meta: meta)
    struct!(__MODULE__, opts)
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Object{fields: fields}, input, opts) when is_map(input) do
      Enum.reduce(fields, {%{}, %{}}, fn {key, type}, {parsed, errors} ->
        case map_fetch(input, key) do
          :error ->
            if optional?(type) do
              # If the field is optional, we skip it and do not add it to parsed
              {parsed, errors}
            else
              {parsed, Map.put(errors, key, Zoi.Error.add_error("is required"))}
            end

          {:ok, value} ->
            case Zoi.parse(type, value, opts) do
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
          {:error, %Zoi.Error{issues: errors}}
        end
      end)
    end

    def parse(_, _, _) do
      {:error, Zoi.Error.add_error("invalid object type")}
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
end
