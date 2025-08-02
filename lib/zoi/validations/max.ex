defprotocol Zoi.Validations.Max do
  @moduledoc false

  @type input_type :: integer()

  @spec new(schema :: Zoi.Type.t(), max :: input_type()) :: Zoi.Type.t()
  def new(schema, max)

  @spec validate(schema :: Zoi.Type.t(), input :: Zoi.input(), max :: input_type()) ::
          :ok | {:error, String.t()}
  def validate(schema, input, max)
end
