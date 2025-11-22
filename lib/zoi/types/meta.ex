defmodule Zoi.Types.Meta do
  @moduledoc false

  @type effect ::
          {:transform, Zoi.transform()}
          | {:refine, Zoi.refinement()}

  @type t :: %__MODULE__{
          effects: [effect()],
          error: binary() | nil,
          required: boolean(),
          description: binary() | nil,
          example: Zoi.input(),
          metadata: [keyword()]
        }

  @struct_fields [
    effects: [],
    metadata: [],
    required: nil,
    error: nil,
    description: nil,
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

  @spec run_effects(ctx :: Zoi.Context.t()) :: {:ok, Zoi.input()} | {:error, [Zoi.Errors.t()]}
  def run_effects(%Zoi.Context{schema: schema, parsed: input} = ctx) do
    schema.meta.effects
    |> Enum.reduce({{:ok, input}, []}, fn
      {:refine, refinement}, {{:ok, input}, errors} ->
        run_refinement(refinement, input, errors, ctx)

      {:transform, transform}, {{:ok, input}, errors} ->
        run_transform(transform, input, errors, ctx)
    end)
    |> then(fn {{:ok, value}, errors} ->
      if Enum.empty?(errors) do
        {:ok, value}
      else
        {:error, errors}
      end
    end)
  end

  # Internal validation which uses Protocols in form of MFA: {ProtocolMod, :validate, [value, opts]}
  defp run_refinement({mod, :validate, args}, input, errors, ctx) do
    case apply(mod, :validate, [ctx.schema, input] ++ args) do
      :ok ->
        {{:ok, input}, errors}

      {:error, err} ->
        {{:ok, input}, Zoi.Errors.add_error(errors, err)}
    end
  end

  defp run_refinement({mod, func, args}, input, errors, ctx) do
    case apply(mod, func, [input] ++ args ++ [[ctx: ctx]]) do
      :ok ->
        {{:ok, input}, errors}

      {:error, err} ->
        {{:ok, input}, Zoi.Errors.add_error(errors, err)}

      %Zoi.Context{} = context ->
        {{:ok, context.parsed}, context.errors}
    end
  end

  defp run_refinement(refine_func, input, errors, ctx) when is_function(refine_func) do
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
  end

  defp run_transform({mod, func, args}, input, errors, ctx) do
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
  end

  defp run_transform(transform_func, input, errors, ctx) when is_function(transform_func) do
    cond do
      is_function(transform_func, 1) ->
        transform_func.(input)

      is_function(transform_func, 2) ->
        transform_func.(input, ctx)
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
  end

  @spec required?(t()) :: boolean()
  def required?(%__MODULE__{required: required}) do
    case required do
      nil -> false
      val -> val
    end
  end

  @spec optional?(t()) :: boolean()
  def optional?(%__MODULE__{} = meta) do
    not required?(meta)
  end
end
