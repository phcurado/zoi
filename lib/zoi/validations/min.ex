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

defimpl Zoi.Validations.Min, for: Zoi.Types.String do
  alias Zoi.Validations

  def new(schema, min) do
    Validations.append_validations(schema, {Zoi.Validations.Min, :validate, [min]})
  end

  def validate(%Zoi.Types.String{}, input, min) do
    if byte_size(input) >= min do
      :ok
    else
      {:error, %Zoi.Error{message: "string is too short, minimum length is #{min}"}}
    end
  end
end

defimpl Zoi.Validations.Min, for: Zoi.Types.Integer do
  alias Zoi.Validations

  def new(schema, min) do
    Validations.append_validations(schema, {Zoi.Validations.Min, :validate, [min]})
  end

  def validate(%Zoi.Types.Integer{}, input, min) do
    if input >= min do
      :ok
    else
      {:error, %Zoi.Error{message: "minimum value is #{min}"}}
    end
  end
end
