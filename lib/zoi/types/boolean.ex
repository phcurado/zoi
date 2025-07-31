defmodule Zoi.Types.Boolean do
  @moduledoc false

  @type t :: %__MODULE__{coerce: boolean(), meta: Zoi.Types.Meta.t()}

  defstruct [:meta, coerce: false]

  @spec new(opts :: keyword()) :: t()
  def new(opts \\ []) do
    {meta, opts} = Zoi.Types.Meta.create_meta(opts)
    struct!(__MODULE__, [{:meta, meta} | opts])
  end

  defimpl Zoi.Type do
    alias Zoi.Validations

    def parse(schema, input, opts) do
      coerce = Keyword.get(opts, :coerce, schema.coerce)

      do_parse(input, coerce)
      |> then(fn
        {:ok, value} ->
          Validations.run_validations(schema, value)

        {:error, _reason} = error ->
          error
      end)
    end

    defp do_parse(input, coerce) do
      cond do
        is_boolean(input) ->
          {:ok, input}

        coerce ->
          coerce_boolean(input)

        true ->
          error()
      end
    end

    defp coerce_boolean(input) do
      cond do
        input in ["true", "1", "yes", "on", "y", "enabled"] ->
          {:ok, true}

        input in ["false", "0", "no", "off", "n", "disabled"] ->
          {:ok, false}

        true ->
          error()
      end
    end

    defp error() do
      {:error, Zoi.Error.add_error("invalid boolean type")}
    end
  end
end
