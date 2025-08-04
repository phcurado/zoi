defmodule Zoi.Types.Meta do
  @moduledoc false

  @type refinement ::
          {module(), atom(), [any()]} | (Zoi.Type.t(), Zoi.input() -> :ok | {:error, binary()})

  @type transform ::
          {module(), atom(), [any()]}
          | (Zoi.Type.t(), Zoi.input() -> {:ok, Zoi.input()} | {:error, binary()} | Zoi.input())

  @type t :: %__MODULE__{
          refinements: [refinement()],
          transforms: [transform()],
          error: nil | binary()
        }

  @struct_fields [refinements: [], transforms: [], error: nil]
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

  @spec run_refinements(schema :: Zoi.Type.t(), input :: Zoi.input()) ::
          {:ok, Zoi.input()} | {:error, binary()}

  def run_refinements(schema, input) do
    schema.meta.refinements
    |> Enum.reduce_while({:ok, input}, fn
      {mod, func, args}, {:ok, _input} ->
        case apply(mod, func, [schema, input] ++ args) do
          :ok -> {:cont, {:ok, input}}
          {:error, err} -> {:halt, {:error, err}}
        end

      refine_func, {:ok, _input} ->
        case refine_func.(schema, input) do
          :ok ->
            {:cont, {:ok, input}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
    end)
  end

  @spec run_transforms(schema :: Zoi.Type.t(), input :: Zoi.input()) ::
          {:ok, Zoi.input()} | {:error, binary()}
  def run_transforms(schema, input) do
    schema.meta.transforms
    |> Enum.reduce_while({:ok, input}, fn
      {mod, func, args}, {:ok, input} ->
        case apply(mod, func, [schema, input] ++ args) do
          {:ok, input} -> {:cont, {:ok, input}}
          {:error, err} -> {:halt, {:error, err}}
          value -> {:cont, {:ok, value}}
        end

      transform_func, {:ok, input} ->
        case transform_func.(schema, input) do
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
