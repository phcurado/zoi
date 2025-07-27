defmodule Zoi.Options do
  @moduledoc """
  Module for handling general options common to all fields.
  #TODO: improve and use this module as main option parser
  """

  @type t :: %__MODULE__{
          strict: boolean(),
          required: boolean()
        }

  defstruct strict: false, required: false

  @spec new(opts :: Keyword.t()) :: t()
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @spec merge(opts_1 :: Keyword.t(), opts_2 :: Keyword.t()) :: t()
  def merge(opts_1, opts_2) do
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
