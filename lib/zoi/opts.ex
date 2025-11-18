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
end
