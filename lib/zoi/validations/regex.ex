defprotocol Zoi.Validations.Regex do
  @moduledoc """
  Protocol for defining validation in Zoi.
  """

  @type input_type :: Regex.t()

  @spec new(schema :: Zoi.Type.t(), regex :: input_type()) :: Zoi.Type.t()
  def new(schema, regex)

  @doc """
  Applies validation on input
  """
  @spec validate(schema :: Zoi.Type.t(), input :: Zoi.input(), regex :: input_type()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, regex)
end
