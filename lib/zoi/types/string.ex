defmodule Zoi.Types.String do
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
        is_binary(input) ->
          {:ok, input}

        coerce ->
          {:ok, to_string(input)}

        true ->
          {:error, Zoi.Error.add_error("invalid string type")}
      end
    end
  end

  # Validations

  defimpl Zoi.Validations.Regex, for: Zoi.Types.String do
    alias Zoi.Validations

    def new(schema, regex) do
      Validations.append_validations(schema, {Zoi.Validations.Regex, :validate, [regex]})
    end

    def validate(%Zoi.Types.String{}, input, regex) do
      if String.match?(input, regex) do
        :ok
      else
        {:error, Zoi.Error.add_error("regex does not match")}
      end
    end
  end

  defimpl Zoi.Validations.Email do
    alias Zoi.Validations

    @email_regex ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i

    def new(schema, opts) do
      Validations.append_validations(schema, {Zoi.Validations.Email, :validate, [opts]})
    end

    def validate(%Zoi.Types.String{} = schema, input, opts) do
      pattern = Keyword.get(opts, :pattern)
      Zoi.Validations.Regex.validate(schema, input, pattern || @email_regex)
    end
  end

  defimpl Zoi.Validations.Min do
    alias Zoi.Validations

    def new(schema, min) do
      Validations.append_validations(schema, {Zoi.Validations.Min, :validate, [min]})
    end

    def validate(%Zoi.Types.String{}, input, min) do
      if byte_size(input) >= min do
        :ok
      else
        {:error, Zoi.Error.add_error("minimum length is #{min}")}
      end
    end
  end

  defimpl Zoi.Validations.Max do
    alias Zoi.Validations

    def new(schema, max) do
      Validations.append_validations(schema, {Zoi.Validations.Max, :validate, [max]})
    end

    def validate(%Zoi.Types.String{}, input, max) do
      if byte_size(input) <= max do
        :ok
      else
        {:error, Zoi.Error.add_error("maximum length is #{max}")}
      end
    end
  end
end
