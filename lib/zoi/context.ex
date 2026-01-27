defmodule Zoi.Context do
  @moduledoc """
  The Context provides the parsing information such as the input data, parsed data and errors.

  The context is passed around during the parsing process to keep track of the current state of parsing.
  It contains the schema being parsed, the input data, the parsed data, the path of the current error and any errors that have occurred during parsing.
  """

  alias Zoi.Types.Meta

  @type t :: %__MODULE__{
          schema: Zoi.schema(),
          input: Zoi.input(),
          parsed: Zoi.input(),
          path: Zoi.Error.path(),
          valid?: boolean() | nil,
          errors: list(Zoi.Error.t())
        }

  @type error :: Zoi.Error.t() | binary() | list(Zoi.Error.t())

  defstruct [:schema, :input, :parsed, :path, valid?: false, errors: []]

  @doc false
  @spec new(Zoi.schema(), Zoi.input()) :: t()
  def new(schema, input) do
    %__MODULE__{
      schema: schema,
      input: input,
      parsed: nil,
      valid?: false,
      path: [],
      errors: []
    }
  end

  @doc false
  @spec parse(t(), opts :: Zoi.options()) :: t()
  def parse(%__MODULE__{} = ctx, opts \\ []) do
    maybe_warn_deprecated(ctx.schema, ctx.path)

    with {:ok, ctx} <- parse_type(ctx, opts),
         {:ok, ctx} <- run_effects(ctx) do
      %{ctx | valid?: true}
    else
      {:error, ctx} -> ctx
    end
  end

  defp maybe_warn_deprecated(%Zoi.Types.Default{inner: inner}, path) do
    maybe_warn_deprecated(inner, path)
  end

  defp maybe_warn_deprecated(schema, path) do
    case Meta.deprecated(schema.meta) do
      nil ->
        :ok

      message ->
        field_name = format_path(path)
        IO.warn("#{field_name} is deprecated: #{message}", Macro.Env.stacktrace(__ENV__))
    end
  end

  defp format_path([]), do: "schema"
  defp format_path(path), do: inspect(List.last(path))

  defp parse_type(ctx, opts) do
    case Zoi.Type.parse(ctx.schema, ctx.input, opts) do
      {:ok, result} ->
        {:ok, add_parsed(ctx, result)}

      {:error, error, partial} ->
        # Type explicitly provided partial (Objects, Arrays, etc)
        {:error, ctx |> add_parsed(partial) |> add_error(error)}

      {:error, error} ->
        # Type didn't provide partial - preserve original input
        {:error, ctx |> add_parsed(ctx.input) |> add_error(error)}
    end
  end

  defp run_effects(ctx) do
    case Meta.run_effects(ctx) do
      {:ok, result} ->
        {:ok, add_parsed(ctx, result)}

      {:error, error} ->
        {:error, add_error(ctx, error)}
    end
  end

  @doc """
  Add a error to the context.

  ## Example

      iex> schema = Zoi.string() |> Zoi.refine(fn input, ctx ->
      ...>   if String.length(input) > 5 do
      ...>     :ok
      ...>   else
      ...>     Zoi.Context.add_error(ctx, "Input too long")
      ...>   end
      ...> end)
      ...> Zoi.parse(schema, "s")
      {:error,
       [
         %Zoi.Error{
           code: :custom,
           issue: {"Input too long", []},
           message: "Input too long",
           path: []
         }
       ]}
  """
  @spec add_error(t(), error()) :: t()
  def add_error(%__MODULE__{errors: errors} = context, error) do
    error = Zoi.Errors.add_error(errors, error)
    %{context | valid?: false, errors: error}
  end

  @doc false
  @spec add_parsed(t(), Zoi.input()) :: t()
  def add_parsed(%__MODULE__{} = context, parsed) do
    %{context | parsed: parsed}
  end

  @doc false
  @spec add_path(t(), Zoi.Error.path()) :: t()
  def add_path(%__MODULE__{} = context, path) do
    %{context | path: path}
  end
end
