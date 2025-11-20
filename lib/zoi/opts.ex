defmodule Zoi.Opts do
  @moduledoc false

  ## Common Metadata

  @spec complex_type_opts() :: Zoi.Type.t()
  def complex_type_opts() do
    opts =
      Zoi.Types.Keyword.new(
        [
          strict:
            Zoi.Types.Boolean.new(
              description: "If strue, unrecognized keys will cause validation to fail."
            )
            |> Zoi.Types.Default.new(false),
          empty_values: empty_values()
        ],
        strict: true
      )
      |> with_coerce()

    Zoi.Types.Extend.new(opts, meta_opts())
  end

  @spec meta_opts() :: Zoi.Type.t()
  def meta_opts() do
    Zoi.Types.Keyword.new(
      [
        description: description(),
        example: example(),
        metadata: metadata(),
        error: error()
      ],
      strict: true
    )
  end

  @spec with_coerce(Zoi.Type.t()) :: Zoi.Type.t()
  def with_coerce(schema) do
    Zoi.Types.Extend.new(schema, Zoi.Types.Keyword.new([coerce: coerce()], coerce: true))
  end

  defp error() do
    Zoi.Types.String.new(description: "Custom error message for validation.")
  end

  defp metadata() do
    Zoi.Types.Keyword.new(Zoi.Types.Any.new(), description: "Additional metadata for the schema.")
  end

  defp coerce() do
    Zoi.Types.Boolean.new(description: "Enable or disable coercion.")
    |> Zoi.Types.Default.new(false)
  end

  defp description() do
    Zoi.Types.String.new(description: "Description of the schema.")
  end

  defp example() do
    Zoi.Types.Any.new(description: "Example value for the schema.")
  end

  defp empty_values() do
    Zoi.Types.Array.new(Zoi.Types.Any.new(),
      description: "List of values to treat as empty and skip during parsing."
    )
  end

  ## Constraint Helpers

  @doc """
  Returns a schema for constraint fields that accept either an integer or a tuple {integer, [error: string]}.
  This pattern is used for min_length, max_length, length, etc.
  """
  @spec constraint_schema() :: Zoi.Type.t()
  def constraint_schema do
    constraint_opts = Zoi.Types.Keyword.new([error: Zoi.Types.String.new([])], strict: true)

    Zoi.Types.Union.new(
      [
        Zoi.Types.Integer.new(description: "Constraint value."),
        Zoi.Types.Tuple.new(
          {Zoi.Types.Integer.new([]), constraint_opts},
          description: "Constraint value with custom options."
        )
      ],
      []
    )
  end

  @doc """
  Extracts the value and options from a constraint field.
  Constraints can be either a plain number or a tuple {number, opts}.
  """
  @spec extract_constraint(number() | {number(), keyword()} | nil) ::
          {number(), keyword()} | {nil, []}
  def extract_constraint({value, opts}) when is_number(value) and is_list(opts),
    do: {value, opts}

  def extract_constraint(value) when is_number(value), do: {value, []}
  def extract_constraint(nil), do: {nil, []}

  @doc """
  Extracts just the value from a constraint field, discarding options.
  Used by JSON Schema encoder and Inspect.
  """
  @spec extract_constraint_value(number() | {number(), keyword()} | nil) :: number() | nil
  def extract_constraint_value({value, _opts}), do: value
  def extract_constraint_value(value), do: value
end
