defmodule Zoi.Opts do
  @moduledoc false

  ## Common Metadata

  @spec complex_type_opts() :: Zoi.Type.t()
  def complex_type_opts() do
    opts =
      Zoi.Types.Keyword.new(
        [
          unrecognized_keys:
            Zoi.Types.Union.new(
              [
                Zoi.Types.Enum.new([:strip, :error, :preserve]),
                Zoi.Types.Tuple.new(
                  {Zoi.Types.Literal.new(:preserve, []),
                   Zoi.Types.Tuple.new({Zoi.Types.Any.new(), Zoi.Types.Any.new()}, [])},
                  []
                )
              ],
              description: """
              How to handle unrecognized keys:
              - `:strip` (default) - removes unrecognized keys
              - `:error` - returns error on unrecognized keys
              - `:preserve` - keeps unrecognized keys as-is
              - `{:preserve, {key_schema, value_schema}}` - preserves and validates both keys and values
              """
            ),
          strict:
            Zoi.Types.Boolean.new(
              description: "If true, unrecognized keys will cause validation to fail.",
              deprecated: "Use :unrecognized_keys option instead."
            ),
          empty_values: empty_values()
        ],
        unrecognized_keys: :error
      )
      |> with_coerce()

    Zoi.Types.Extend.new(opts, meta_opts())
  end

  @spec meta_opts() :: Zoi.Type.t()
  def meta_opts() do
    Zoi.Types.Keyword.new(
      [
        description: description(),
        title: title(),
        example: example(),
        examples: examples(),
        read_only: boolean_flag("Marks the schema as read-only."),
        write_only: boolean_flag("Marks the schema as write-only."),
        id: string_meta("Schema identifier emitted as $id."),
        comment: string_meta("Schema comment emitted as $comment."),
        metadata: metadata(),
        error: error(),
        typespec: typespec(),
        deprecated: deprecated()
      ],
      unrecognized_keys: :error
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

  defp title() do
    Zoi.Types.String.new(description: "Title of the schema.")
  end

  defp example() do
    Zoi.Types.Any.new(description: "Example value for the schema.")
  end

  defp examples() do
    Zoi.Types.Array.new(Zoi.Types.Any.new(),
      description: "List of example values for the schema."
    )
  end

  defp boolean_flag(description) do
    Zoi.Types.Boolean.new(description: description)
  end

  defp string_meta(description) do
    Zoi.Types.String.new(description: description)
  end

  defp typespec() do
    Zoi.Types.Macro.new(description: "Custom typespec to override generated type.")
  end

  defp deprecated() do
    Zoi.Types.String.new(description: "Deprecation message to warn when this option is used.")
  end

  defp empty_values() do
    Zoi.Types.Array.new(Zoi.Types.Any.new(),
      description: "List of values to treat as empty and skip during parsing."
    )
  end

  ## Constraint Helpers

  @spec constraint_schema(Zoi.Type.t(), keyword()) :: Zoi.Type.t()
  def constraint_schema(internal_schema, opts \\ []) do
    custom_opts = Zoi.Types.Keyword.new([error: error()], unrecognized_keys: :error)

    Zoi.Types.Union.new(
      [
        internal_schema,
        Zoi.Types.Tuple.new(
          {internal_schema, custom_opts},
          []
        )
      ],
      opts
    )
  end
end
