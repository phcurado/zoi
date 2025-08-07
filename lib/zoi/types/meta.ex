defmodule Zoi.Types.Meta do
  @moduledoc false

  @type t :: %__MODULE__{
          refinements: [Zoi.refinement()],
          transforms: [Zoi.transform()],
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
    |> Enum.reduce({{:ok, input}, []}, fn
      {mod, func, args}, {{:ok, input}, errors} ->
        case apply(mod, func, [schema, input] ++ args) do
          :ok ->
            {{:ok, input}, errors}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(errors, err)}
        end

      refine_func, {{:ok, input}, error} ->
        case refine_func.(schema, input) do
          :ok ->
            {{:ok, input}, error}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(error, err)}
        end
    end)
    |> then(fn {{:ok, value}, errors} ->
      if Enum.empty?(errors) do
        {:ok, value}
      else
        {:error, errors}
      end
    end)
  end

  @spec run_transforms(schema :: Zoi.Type.t(), input :: Zoi.input()) ::
          {:ok, Zoi.input()} | {:error, binary()}
  def run_transforms(schema, input) do
    schema.meta.transforms
    |> Enum.reduce({{:ok, input}, []}, fn
      {mod, func, args}, {{:ok, input}, error} ->
        case apply(mod, func, [schema, input] ++ args) do
          {:ok, value} ->
            {{:ok, value}, error}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(error, err)}

          value ->
            {{:ok, value}, error}
        end

      transform_func, {{:ok, input}, error} ->
        case transform_func.(schema, input) do
          {:ok, value} ->
            {{:ok, value}, error}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(error, err)}

          value ->
            {{:ok, value}, error}
        end
    end)
    |> then(fn {{:ok, value}, errors} ->
      if Enum.empty?(errors) do
        {:ok, value}
      else
        {:error, errors}
      end
    end)
  end
end
