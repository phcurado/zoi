defmodule Zoi.Types.Macro do
  @moduledoc false

  use Zoi.Type.Def

  def opts() do
    Zoi.Opts.meta_opts()
  end

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(schema, input, _opts) do
      case Macro.validate(input) do
        :ok -> {:ok, input}
        {:error, _} -> {:error, Zoi.Error.invalid_type(:macro, error: schema.meta.error)}
      end
    end
  end

  defimpl Zoi.TypeSpec do
    def spec(_schema, _opts) do
      quote(do: Macro.t())
    end
  end

  defimpl Inspect do
    def inspect(type, opts) do
      Zoi.Inspect.build(type, opts)
    end
  end

  defimpl Zoi.Describe.Encoder do
    def encode(_schema), do: "`t:Macro.t/0`"
  end
end
