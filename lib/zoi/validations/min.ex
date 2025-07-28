defprotocol Zoi.Validations.Min do
  @moduledoc """
  Protocol for defining validation in Zoi.
  """

  @type input_type :: integer()

  @spec new(schema :: Zoi.Type.t(), min :: input_type()) :: Zoi.Type.t()
  def new(schema, min)

  @doc """
  Applies validation on input
  """
  @spec validate(schema :: Zoi.Type.t(), input :: Zoi.input(), min :: input_type()) ::
          :ok | {:error, String.t()}
  def validate(schema, input, min)
end
