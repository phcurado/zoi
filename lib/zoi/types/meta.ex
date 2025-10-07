defmodule Zoi.Types.Meta do
  @moduledoc false

  @type t :: %__MODULE__{
          refinements: [Zoi.refinement()],
          transforms: [Zoi.transform()],
          error: nil | binary(),
          required: boolean(),
          example: Zoi.input(),
          metadata: [keyword()]
        }

  @struct_fields [
    refinements: [],
    transforms: [],
    metadata: [],
    required: nil,
    error: nil,
    example: nil
  ]
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

  @spec run_refinements(schema :: Zoi.Type.t(), ctx :: Zoi.Context.t()) ::
          {:ok, Zoi.input()} | {:error, [Zoi.Errors.t()]}
  def run_refinements(schema, %Zoi.Context{parsed: input} = ctx) do
    schema.meta.refinements
    |> Enum.reduce({{:ok, input}, []}, fn
      {mod, func, args}, {{:ok, input}, errors} ->
        case apply(mod, func, [input] ++ args ++ [[ctx: ctx]]) do
          :ok ->
            {{:ok, input}, errors}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(errors, err)}

          %Zoi.Context{} = context ->
            {{:ok, context.parsed}, context.errors}
        end

      refine_func, {{:ok, input}, errors} ->
        cond do
          is_function(refine_func, 1) ->
            refine_func.(input)

          is_function(refine_func, 2) ->
            refine_func.(input, ctx)
        end
        |> case do
          :ok ->
            {{:ok, input}, errors}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(errors, err)}

          %Zoi.Context{} = context ->
            {{:ok, context.parsed}, context.errors}
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

  @spec run_transforms(schema :: Zoi.Type.t(), ctx :: Zoi.Context.t()) ::
          {:ok, Zoi.input()} | {:error, [Zoi.Errors.t()]}
  def run_transforms(schema, %Zoi.Context{parsed: input} = ctx) do
    schema.meta.transforms
    |> Enum.reduce({{:ok, input}, []}, fn
      {mod, func, args}, {{:ok, input}, errors} ->
        case apply(mod, func, [input] ++ args ++ [[ctx: ctx]]) do
          {:ok, value} ->
            {{:ok, value}, errors}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(errors, err)}

          %Zoi.Context{} = context ->
            {{:ok, context.parsed}, context.errors}

          value ->
            {{:ok, value}, errors}
        end

      refine_func, {{:ok, input}, errors} ->
        cond do
          is_function(refine_func, 1) ->
            refine_func.(input)

          is_function(refine_func, 2) ->
            refine_func.(input, ctx)
        end
        |> case do
          {:ok, value} ->
            {{:ok, value}, errors}

          {:error, err} ->
            {{:ok, input}, Zoi.Errors.add_error(errors, err)}

          %Zoi.Context{} = context ->
            {{:ok, context.parsed}, context.errors}

          value ->
            {{:ok, value}, errors}
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

  @spec required?(t()) :: boolean()
  def required?(%__MODULE__{required: required}) do
    case required do
      nil -> false
      val -> val
    end
  end
end
