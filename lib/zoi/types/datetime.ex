defmodule Zoi.Types.Datetime do
  @moduledoc false
  use Zoi.Type.Def

  def new(opts \\ []) do
    apply_type(opts)
  end

  # TO_DO: think what if we should add extra opts
  # like `unit` by default seconds is used and Calendar by default ISO calendar is used.

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Datetime{}, input, _opts)
        when is_binary(input) do
      # TO_DO: add opts
      case DateTime.from_iso8601(input) do
        {:ok, _parsed, _offset} -> {:ok, input}
        {:error, atom} -> {:error, "Invalid iso string datetime: #{atom}"}
      end
    end

    def parse(%Zoi.Types.Datetime{}, _input, _opts) do
      {:error, "invalid datetime type"}
    end
  end
end
