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
          title: binary() | nil,
          example: Zoi.input(),
          examples: [Zoi.input()] | nil,
          read_only: boolean() | nil,
          write_only: boolean() | nil,
          id: binary() | nil,
          comment: binary() | nil,
          metadata: [keyword()],
          typespec: Macro.t() | nil,
          deprecated: binary() | nil
        }

  @struct_fields [
    effects: [],
    metadata: [],
    required: nil,
    error: nil,
    description: nil,
    title: nil,
    example: nil,
    examples: nil,
    read_only: nil,
    write_only: nil,
    id: nil,
    comment: nil,
    typespec: nil,
    deprecated: nil
  ]
  @struct_keys Keyword.keys(@struct_fields)

  defstruct @struct_fields

  # When we propagate the meta schema fields to other schemas, these are the allowed keys
  # An example is when using nullable type, which is a union under the hood. We should be able
  # to propagate these fields to the union since nullable is a behavior
  @propagate_keys [
    :required,
    :description,
    :title,
    :example,
    :examples,
    :read_only,
    :write_only,
    :id,
    :comment,
    :metadata,
    :typespec,
    :deprecated,
    :error
  ]

  @spec create_meta(keyword()) :: {t(), keyword()}
  def create_meta(opts) do
    {meta_opts, rest_opts} = split_keyword(opts)
    {struct!(__MODULE__, meta_opts), rest_opts}
  end

  @spec propagate_opts(t()) :: keyword()
  def propagate_opts(%__MODULE__{} = meta) do
    meta
    |> Map.take(@propagate_keys)
    |> Enum.reject(fn {_k, v} -> v == nil end)
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

  @spec run_effects(Zoi.Context.t()) :: {:ok, Zoi.Context.t()} | {:error, Zoi.Context.t()}
  def run_effects(%Zoi.Context{schema: schema} = ctx) do
    {ctx, has_partial} =
      Enum.reduce(schema.meta.effects, {ctx, false}, fn
        {:refine, refinement}, {ctx, has_partial} ->
          case run_refinement(refinement, ctx.parsed, ctx) do
            {:ok, value} ->
              {Zoi.Context.add_parsed(ctx, value), has_partial}

            {:error, errors} ->
              {Zoi.Context.add_error(ctx, errors), has_partial}

            {:error, errors, partial} ->
              {ctx |> Zoi.Context.add_parsed(partial) |> Zoi.Context.add_error(errors), true}
          end

        {:transform, transform}, {ctx, has_partial} ->
          case run_transform(transform, ctx.parsed, ctx) do
            {:ok, value} ->
              {Zoi.Context.add_parsed(ctx, value), has_partial}

            {:error, errors} ->
              {Zoi.Context.add_error(ctx, errors), has_partial}

            {:error, errors, partial} ->
              {ctx |> Zoi.Context.add_parsed(partial) |> Zoi.Context.add_error(errors), true}
          end
      end)

    cond do
      ctx.errors == [] -> {:ok, ctx}
      has_partial -> {:error, ctx}
      true -> {:error, %{ctx | parsed: nil}}
    end
  end

  # Internal validation which uses Protocols in form of MFA: {ProtocolMod, :validate, [value, opts]}
  defp run_refinement({mod, :validate, args}, input, ctx) do
    case apply(mod, :validate, [ctx.schema, input] ++ args) do
      :ok ->
        {:ok, input}

      {:error, err} ->
        {:error, Zoi.Errors.add_error(err)}
    end
  end

  defp run_refinement({mod, func, args}, input, ctx) do
    case apply(mod, func, [input] ++ args ++ [[ctx: ctx]]) do
      :ok ->
        {:ok, input}

      {:error, err} ->
        {:error, Zoi.Errors.add_error(err)}

      {:error, err, partial} ->
        {:error, Zoi.Errors.add_error(err), partial}

      %Zoi.Context{valid?: true, parsed: value} ->
        {:ok, value}

      %Zoi.Context{errors: errors, parsed: ^input} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: nil} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: partial} ->
        {:error, errors, partial}
    end
  end

  defp run_refinement(refine_func, input, ctx) when is_function(refine_func) do
    result =
      cond do
        is_function(refine_func, 1) ->
          refine_func.(input)

        is_function(refine_func, 2) ->
          refine_func.(input, ctx)
      end

    case result do
      :ok ->
        {:ok, input}

      {:error, err} ->
        {:error, Zoi.Errors.add_error(err)}

      {:error, err, partial} ->
        {:error, Zoi.Errors.add_error(err), partial}

      %Zoi.Context{valid?: true, parsed: value} ->
        {:ok, value}

      %Zoi.Context{errors: errors, parsed: ^input} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: nil} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: partial} ->
        {:error, errors, partial}
    end
  end

  defp run_transform({mod, func, args}, input, ctx) do
    case apply(mod, func, [input] ++ args ++ [[ctx: ctx]]) do
      {:ok, value} ->
        {:ok, value}

      {:error, err} ->
        {:error, Zoi.Errors.add_error(err)}

      {:error, err, partial} ->
        {:error, Zoi.Errors.add_error(err), partial}

      %Zoi.Context{valid?: true, parsed: value} ->
        {:ok, value}

      %Zoi.Context{errors: errors, parsed: ^input} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: nil} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: partial} ->
        {:error, errors, partial}

      value ->
        {:ok, value}
    end
  end

  defp run_transform(transform_func, input, ctx) when is_function(transform_func) do
    result =
      cond do
        is_function(transform_func, 1) ->
          transform_func.(input)

        is_function(transform_func, 2) ->
          transform_func.(input, ctx)
      end

    case result do
      {:ok, value} ->
        {:ok, value}

      {:error, err} ->
        {:error, Zoi.Errors.add_error(err)}

      {:error, err, partial} ->
        {:error, Zoi.Errors.add_error(err), partial}

      %Zoi.Context{valid?: true, parsed: value} ->
        {:ok, value}

      %Zoi.Context{errors: errors, parsed: ^input} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: nil} ->
        {:error, errors}

      %Zoi.Context{errors: errors, parsed: partial} ->
        {:error, errors, partial}

      value ->
        {:ok, value}
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

  @spec deprecated(t()) :: binary() | nil
  def deprecated(%__MODULE__{deprecated: deprecated}), do: deprecated

  @spec deprecated?(t()) :: boolean()
  def deprecated?(%__MODULE__{deprecated: deprecated}) do
    deprecated not in [nil, false]
  end
end
