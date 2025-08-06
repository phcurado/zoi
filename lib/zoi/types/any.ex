defmodule Zoi.Types.Any do
  @moduledoc false
  use Zoi.Type.Def

  def new(opts \\ []) do
    apply_type(opts)
  end

  defimpl Zoi.Type do
    def parse(%Zoi.Types.Any{}, value, _opts), do: {:ok, value}
  end
end
