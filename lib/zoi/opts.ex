defmodule Zoi.Opts do
  @moduledoc false

  # Type opts
  def string(), do: Zoi.Types.Keyword.new(shared_metadata(), [])
  def integer(), do: Zoi.Types.Keyword.new(shared_metadata(), [])
  def float(), do: Zoi.Types.Keyword.new(shared_metadata(), [])

  def keyword() do
    Keyword.merge(shared_metadata(),
      strict:
        Zoi.Types.Boolean.new(
          description: "If strue, unrecognized keys will cause validation to fail."
        )
        |> Zoi.Types.Default.new(false),
      empty_values: empty_values()
    )
    |> Zoi.Types.Keyword.new([])
  end

  ## Common Metadata
  def shared_metadata() do
    [
      coerce: coerce(),
      description: description(),
      example: example(),
      metadata: metadata(),
      error: error()
    ]
  end

  def error() do
    Zoi.Types.String.new(description: "Custom error message for validation")
  end

  def metadata() do
    Zoi.Types.Keyword.new(Zoi.Types.Any.new(), description: "Additional metadata for the schema")
  end

  def coerce() do
    Zoi.Types.Boolean.new(description: "Enable or disable coercion")
    |> Zoi.Types.Default.new(false)
  end

  def description() do
    Zoi.Types.String.new(description: "Description of the schema")
  end

  def example() do
    Zoi.Types.Any.new(description: "Example value for the schema")
  end

  def empty_values() do
    Zoi.Types.Array.new(Zoi.Types.Any.new(),
      description: "List of values to treat as empty and skip during parsing"
    )
  end
end
