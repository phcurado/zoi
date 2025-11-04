defmodule Zoi.Form do
  @moduledoc """
  This module contains some helpers for integrating with html forms.
  """

  def enchance(%Zoi.Types.Object{} = obj) do
    %{obj | coerce: true, empty_values: [nil, ""]}
  end

  def parse(%Zoi.Types.Object{} = obj, input, opts \\ []) do
    ctx = Zoi.Context.new(obj, input)
    opts = Keyword.put_new(opts, :ctx, ctx)

    Zoi.Context.parse(ctx, opts)
  end
end
