defprotocol Zoi.Validations.Max do
  @moduledoc """
  Protocol for defining validation in Zoi.
  """

  @type input_type :: integer()

  @spec new(schema :: Zoi.Type.t(), max :: input_type()) :: Zoi.Type.t()
  def new(schema, max)

  @doc """
  Applies validation on input
  """
  @spec validate(schema :: Zod.Type.t(), input :: Zoi.input(), max :: input_type()) ::
          :ok | {:error, String.t()}
  def validate(schema, input, max)
end

defimpl Zoi.Validations.Max, for: Zoi.Types.String do
  alias Zoi.Validations

  def new(schema, max) do
    Validations.append_validations(schema, {Zoi.Validations.Max, :validate, [max]})
  end

  def validate(%Zoi.Types.String{}, input, max) do
    if byte_size(input) <= max do
      :ok
    else
      {:error, %Zoi.Error{message: "string is too bing, maximum length is #{max}"}}
    end
  end
end

defimpl Zoi.Validations.Max, for: Zoi.Types.Integer do
  alias Zoi.Validations

  def new(schema, max) do
    Validations.append_validations(schema, {Zoi.Validations.Max, :validate, [max]})
  end

  def validate(%Zoi.Types.Integer{}, input, max) do
    if input <= max do
      :ok
    else
      {:error, %Zoi.Error{message: "maximum value is #{max}"}}
    end
  end
end
