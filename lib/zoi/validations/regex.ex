defprotocol Zoi.Validations.Regex do
  @moduledoc false
  @type input_type :: Regex.t()

  @spec new(schema :: Zoi.Type.t(), regex :: input_type()) :: Zoi.Type.t()
  def new(schema, regex)

  @spec validate(schema :: Zoi.Type.t(), input :: Zoi.input(), regex :: input_type()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, regex)
end
