defmodule Zoi.Context do
  @moduledoc """
  The Context provides the parsing information such as the input data, parsed data and errors.

  The context is passed around during the parsing process to keep track of the current state of parsing.
  It contains the schema being parsed, the input data, the parsed data, the path of the current error and any errors that have occurred during parsing.
  """
  @type t :: %__MODULE__{
          schema: Zoi.Type.t(),
          input: Zoi.input(),
          parsed: Zoi.input(),
          path: Zoi.Error.path(),
          errors: list(Zoi.Error.t())
        }

  @type error :: Zoi.Error.t() | binary() | list(Zoi.Error.t())

  defstruct [:schema, :input, :parsed, :path, :errors]

  @doc false
  @spec new(Zoi.Type.t(), Zoi.input()) :: t()
  def new(schema, input) do
    %__MODULE__{
      schema: schema,
      input: input,
      parsed: nil,
      path: [],
      errors: []
    }
  end

  @doc """
  Add a error to the context.

  ## Example

      iex> schema = Zoi.string() |> Zoi.refine(fn input, ctx ->
      ...>   if String.length(input) > 5 do
      ...>     :ok
      ...>   else
      ...>     Zoi.Context.add_error(ctx, %Zoi.Error{message: "Input too long"})
      ...>   end
      ...> end)
      ...> Zoi.parse(schema, "s")
      {:error, [%Zoi.Error{message: "Input too long"}]}
  """
  @spec add_error(t(), error()) :: t()
  def add_error(%__MODULE__{errors: errors} = context, error) do
    error = Zoi.Errors.add_error(errors, error)
    %{context | errors: error}
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
