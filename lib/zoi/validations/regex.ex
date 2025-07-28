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
  @spec validate(schema :: Zoi.Type.t(), input :: Zod.input(), regex :: input_type()) ::
          :ok | {:error, Zoi.Error.t()}
  def validate(schema, input, regex)
end

defimpl Zoi.Validations.Regex, for: Zoi.Types.String do
  alias Zoi.Validations

  def new(schema, regex) do
    Validations.append_validations(schema, {Zoi.Validations.Regex, :validate, [regex]})
  end

  def validate(%Zoi.Types.String{}, input, regex) do
    if String.match?(input, regex) do
      :ok
    else
      {:error, %Zoi.Error{message: "regex does not match"}}
    end
  end
end
