defmodule Zoi.Context do
  @moduledoc """
  The Context provides the parsing information such as the input data, parsed data and errors.
  """
  @type t :: %__MODULE__{
          schema: Zoi.Type.t(),
          input: Zoi.input(),
          parsed: Zoi.input(),
          path: Zoi.Error.path(),
          errors: list(Zoi.Error.t())
        }

  defstruct [:schema, :input, :parsed, :path, :errors]

  @doc """
  Creates a new context with the given schema and input.
  """
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
  """
  @spec add_error(t(), Zoi.Errors.error()) :: t()
  def add_error(%__MODULE__{errors: errors} = context, error) do
    error = Zoi.Errors.add_error(errors, error)
    %{context | errors: error}
  end

  @spec add_parsed(t(), Zoi.input()) :: t()
  def add_parsed(%__MODULE__{} = context, parsed) do
    %{context | parsed: parsed}
  end

  @spec add_path(t(), Zoi.Error.path()) :: t()
  def add_path(%__MODULE__{} = context, path) do
    %{context | path: path}
  end
end
