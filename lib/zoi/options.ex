defmodule Zoi.Options do
  @moduledoc """
  Module for handling general options common to all fields.
  #TODO: improve and use this module as main option parser
  """

  @type t :: %__MODULE__{
          coerce: boolean()
        }

  defstruct [:coerce]

  @spec new(opts :: Keyword.t()) :: t()
  def new(opts \\ []) do
    opts = Keyword.validate!(opts, [:coerce])
    struct!(__MODULE__, opts)
  end

  @spec merge(opts_1 :: Keyword.t(), opts_2 :: Keyword.t()) :: t()
  def merge(opts_1, opts_2) when is_list(opts_1) and is_list(opts_2) do
    # Merging the global options with type-specific options
    # The type-specific options can override the global ones

    opts_2
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> then(fn default_opts -> Keyword.validate!(opts_1, default_opts) end)
    |> then(fn validated_opts ->
      struct!(__MODULE__, validated_opts)
    end)
  end
end
