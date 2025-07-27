defprotocol Zoi.Validations.Min do
  @moduledoc """
  Protocol for defining validation in Zoi.
  """

  @spec new(schema :: any(), min :: integer()) :: any()
  def new(schema, min)

  @doc """
  Applies validation on input
  """
  @spec validate(schema :: any(), input :: any(), min :: integer()) ::
          :ok | {:error, String.t()}
  def validate(schema, input, min)
end

defimpl Zoi.Validations.Min, for: Zoi.Types.String do
  alias Zoi.Validations

  def new(%Zoi.Types.String{validations: validations} = schema, min) do
    validations =
      Validations.append_validations(validations, {Zoi.Validations.Min, :validate, [min]})

    %Zoi.Types.String{schema | validations: validations}
  end

  def validate(%Zoi.Types.String{}, input, min) do
    if byte_size(input) >= min do
      :ok
    else
      {:error, %Zoi.Error{message: "string is too short, minimum length is #{min}"}}
    end
  end
end
