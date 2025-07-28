defprotocol Zoi.Validations.Email do
  @moduledoc """
  Protocol for defining validation in Zoi.
  """

  @type opts :: keyword()

  @spec new(schema :: Zoi.Type.t(), opts :: opts) :: Zoi.Type.t()
  def new(schema, regex)

  @doc """
  Applies validation on input
  """
  @spec validate(schema :: Zoi.Type.t(), input :: Zoi.input(), opts :: opts()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, regex)
end

defimpl Zoi.Validations.Email, for: Zoi.Types.String do
  alias Zoi.Validations

  @email_regex ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i

  def new(schema, opts) do
    Validations.append_validations(schema, {Zoi.Validations.Email, :validate, [opts]})
  end

  def validate(%Zoi.Types.String{} = schema, input, _opts) do
    Zoi.Validations.Regex.validate(schema, input, @email_regex)
  end
end
