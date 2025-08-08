defmodule Zoi.Types.Datetime do
  @moduledoc false
  use Zoi.Type.Def, fields: [:format]

  def new(format, opts \\ []) do
    apply_type(opts ++ [format: format])
  end

  # TO_DO: think what if we should add extra opts
  # like `unit` by default seconds is used and Calendar by default ISO calendar is used.

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Datetime{format: %Zoi.Types.String{}}, input, _opts)
        when is_binary(input) do
      # TO_DO: add opts
      case DateTime.from_iso8601(input) do
        {:ok, _parsed, _offset} -> {:ok, input}
        {:error, atom} -> {:error, "Invalid iso string datetime: #{atom}"}
      end
    end

    def parse(%Zoi.Types.Datetime{format: %Zoi.Types.String{}}, _, _) do
      {:error, "invalid iso string datetime type"}
    end

    # Unix times are always in UTC and therefore the DateTime will be returned in UTC.
    def parse(%Zoi.Types.Datetime{format: %Zoi.Types.Integer{}}, input, _opts)
        when is_integer(input) do
      # TO_DO: add opts
      case DateTime.from_unix(input) do
        {:ok, _parsed} -> {:ok, input}
        {:error, atom} -> {:error, "Invalid unix timestamp: #{atom}"}
      end
    end

    def parse(%Zoi.Types.Datetime{format: %Zoi.Types.Integer{}}, _input, _opts) do
      {:error, "invalid unix datetime type"}
    end

    def parse(%Zoi.Types.Datetime{format: nil}, %DateTime{} = input, _opts) do
      {:ok, input}
    end

    def parse(%Zoi.Types.Datetime{format: nil}, _input, _opts) do
      {:error, "invalid datetime type"}
    end

    def parse(%Zoi.Types.Datetime{format: _format}, _input, _opts) do
      {:error, "invalid format datetime type"}
    end
  end
end
