defmodule Zoi.Type.Def do
  @moduledoc false
  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])

    quote do
      defstruct unquote(fields) ++ [meta: %Zoi.Types.Meta{}]

      def apply_type(opts \\ []) do
        {meta, opts} = Zoi.Types.Meta.create_meta(opts)
        opts = Keyword.merge(opts, meta: meta)
        struct!(__MODULE__, opts)
      end
    end
  end
end
