defmodule Zoi.Types.Meta do
  @moduledoc false

  @type t :: %__MODULE__{validations: [mfa()]}
  @struct_fields [validations: [], transforms: []]
  @struct_keys Keyword.keys(@struct_fields)

  defstruct @struct_fields

  @spec create_meta(keyword()) :: {t(), keyword()}
  def create_meta(opts) do
    {meta_opts, rest_opts} = split_keyword(opts)
    {struct!(__MODULE__, meta_opts), rest_opts}
  end

  defp split_keyword(opts) when is_list(opts) do
    Enum.reduce(opts, {[], []}, fn {k, v}, {meta_opts, rest_opts} ->
      if k in @struct_keys do
        {Keyword.put(meta_opts, k, v), rest_opts}
      else
        {meta_opts, Keyword.put(rest_opts, k, v)}
      end
    end)
  end

  @spec append_validations(schema :: Zoi.Type.t(), validation :: {module(), atom(), [any()]}) ::
          Zoi.Type.t()
  def append_validations(schema, validation) do
    update_in(schema.meta.validations, fn validations ->
      validations ++ [validation]
    end)
  end

  @doc """
  Runs a list of validations against the input.
  """
  @spec run_validations(schema :: Zoi.Type.t(), input :: Zoi.input()) ::
          {:ok, Zoi.input()} | {:error, binary()}
  def run_validations(schema, input) do
    schema.meta.validations
    |> Enum.reduce_while({:ok, input}, fn
      {:refine, fun, opts}, {:ok, _input} ->
        case fun.(input, opts) do
          :ok ->
            {:cont, {:ok, input}}

          {:error, error} ->
            {:halt, {:error, error}}
        end

      {mod, func, args}, {:ok, _input} ->
        case apply(mod, func, [schema, input] ++ args) do
          :ok -> {:cont, {:ok, input}}
          {:error, err} -> {:halt, {:error, err}}
        end
    end)
  end

  @spec append_transforms(schema :: Zoi.Type.t(), transform :: (any() -> any())) :: Zoi.Type.t()
  def append_transforms(schema, transform) do
    update_in(schema.meta.transforms, fn transforms ->
      transforms ++ [transform]
    end)
  end

  @doc """
  Runs a list of transforms against the input.
  """
  @spec run_transforms(schema :: Zoi.Type.t(), input :: Zoi.input()) ::
          {:ok, Zoi.input()} | {:error, binary()}
  def run_transforms(schema, input) do
    schema.meta.transforms
    |> Enum.reduce_while({:ok, input}, fn transform, {:ok, input} ->
      case transform.(input) do
        {:ok, result} ->
          {:cont, {:ok, result}}

        {:error, err} ->
          {:halt, {:error, err}}

        result ->
          {:cont, {:ok, result}}
      end
    end)
  end
end
