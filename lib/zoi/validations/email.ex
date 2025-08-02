defprotocol Zoi.Validations.Email do
  @moduledoc false
  @type opts :: keyword()

  @spec new(schema :: Zoi.Type.t(), opts :: opts) :: Zoi.Type.t()
  def new(schema, regex)

  @spec validate(schema :: Zoi.Type.t(), input :: Zoi.input(), opts :: opts()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, opts \\ [])
end
