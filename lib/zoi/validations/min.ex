defprotocol Zoi.Validations.Min do
  @moduledoc false
  @type input_type :: integer()

  @spec new(schema :: Zoi.Type.t(), min :: input_type()) :: Zoi.Type.t()
  def new(schema, min)

  @spec validate(schema :: Zoi.Type.t(), input :: Zoi.input(), min :: input_type()) ::
          :ok | {:error, String.t()}
  def validate(schema, input, min)
end
