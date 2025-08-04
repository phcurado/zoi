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
    |> Enum.map(fn
      {mod, func, args} ->
        apply(mod, func, [schema, input] ++ args)

      refine_func ->
        refine_func.(schema, input)
    end)
    |> Enum.filter(fn elem -> elem != :ok end)
    |> then(fn
      [] -> {:ok, input}
      errors -> {:error, errors}
    end)
  end

  @spec run_transforms(schema :: Zoi.Type.t(), input :: Zoi.input()) ::
          {:ok, Zoi.input()} | {:error, binary()}
  def run_transforms(schema, input) do
    schema.meta.transforms
    |> Enum.reduce_while(input, fn
      {_mod, _func, _args}, {:error, error} ->
        {:halt, {:error, %Zoi.Error{message: error}}}

      {mod, func, args}, value ->
        {:cont, apply(mod, func, [schema, value] ++ args)}

      _transform_func, {:error, error} ->
        {:halt, {:error, %Zoi.Error{message: error}}}

      transform_func, value ->
        {:cont, transform_func.(schema, value)}
    end)
    |> then(fn
      {:error, %Zoi.Error{} = error} -> {:error, [error]}
      {:error, error} -> {:error, [%Zoi.Error{message: error}]}
      value -> {:ok, value}
    end)
  end
end
