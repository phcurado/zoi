if Code.ensure_loaded?(Ecto) do
  defmodule Zoi.Ecto do
    @moduledoc """
    A bridge between Zoi parse errors and Ecto changesets.

    Converts a list of `%Zoi.Error{}` structs (as returned by `Zoi.parse/2`)
    into an `%Ecto.Changeset{}`. Nested error paths produce nested changesets,
    matching the structure that `Phoenix`, `Absinthe`, and `LiveView` expect.

    Error opts are structured to match Ecto's native changeset format: each
    error carries `validation:` and (where applicable) `kind:` keys, plus
    the original Zoi `code:` for programmatic matching. Message templates
    retain `%{key}` placeholders so `Ecto.Changeset.traverse_errors/2` can
    interpolate them using the standard pattern.

    ## Usage

        case Zoi.parse(schema, input) do
          {:ok, parsed} ->
            {:ok, parsed}

          {:error, errors} ->
            {:error, Zoi.Ecto.errors_to_changeset(errors)}
        end

    ## Ecto compatibility

    The produced changeset errors use Ecto's `{template, keyword_list}` format.
    The keyword list always includes:

    - `:validation` -- maps to Ecto's validation name (`:required`, `:format`,
      `:number`, `:length`, `:inclusion`, `:cast`, `:custom`, `:unknown_field`)
    - `:kind` -- present for numeric/length constraints (`:greater_than`,
      `:greater_than_or_equal_to`, `:less_than`, `:less_than_or_equal_to`, `:is`)
    - `:code` -- the original Zoi error code atom is preserved
    - Any interpolation params from the Zoi error (`:count`, `:key`, `:values`, etc.)

    Size constraints (min/max) are mapped to `validation: :length` or
    `validation: :number` based on Zoi's error message templates. String
    constraints include "character(s)" and array constraints include "item(s)"
    in their templates, which distinguishes them from numeric constraints.

    ## Known limitations

    - **Unknown codes:** Zoi error codes not in the mapping table are passed
      through with `code:` only -- no `validation:` key is added.
    - **Array errors:** Array item errors produce a list of changesets matching
      Ecto's `embeds_many` convention. Positions without errors get empty valid
      changesets (no parsed data) because Zoi's parse API does not expose
      partial results on failure -- only the error list is available. This means
      valid array items will have empty `.changes` rather than their parsed
      values. Error traversal and rendering are unaffected.
    - **Enum value splitting:** For inclusion errors, the `enum:` key is
      produced by splitting Zoi's comma-joined `values` string back into a
      list. Enum values containing `", "` (comma-space) will be split
      incorrectly.
    - **Length errors lack `type:` key:** Ecto's `validate_length/3` includes
      `type: :string` or `type: :list` in error opts. Zoi's error issue opts
      do not include the target type, so length errors produced by this module
      will not have a `:type` key. Consumers that check `opts[:type]` on
      length errors will get `nil`.
    - **Numeric `number:` key derived from `count:`:** For numeric validation
      errors, Ecto uses `number: target_value`. Zoi uses `count: value`. This
      module copies `count:` into `number:` for Ecto compatibility -- both
      keys are present in the output.
    - **Template coupling:** Size constraint disambiguation (`:number` vs
      `:length`) relies on Zoi's error message templates containing
      "character(s)" or "item(s)" for string/array constraints. If Zoi
      changes these templates in a future version, the mapping may need
      updating.
    """

    @code_mapping %{
      required: [validation: :required],
      invalid_type: [validation: :cast],
      invalid_format: [validation: :format],
      invalid_enum_value: [validation: :inclusion],
      invalid_length: [validation: :length, kind: :is],
      greater_than: [kind: :greater_than],
      greater_than_or_equal_to: [kind: :greater_than_or_equal_to],
      less_than: [kind: :less_than],
      less_than_or_equal_to: [kind: :less_than_or_equal_to],
      unrecognized_key: [validation: :unknown_field],
      custom: [validation: :custom]
    }

    @size_codes [
      :greater_than,
      :greater_than_or_equal_to,
      :less_than,
      :less_than_or_equal_to
    ]

    @doc """
    Parses input through a Zoi schema and returns an Ecto changeset.

    On success, returns a valid changeset with the parsed data.
    On failure, returns an invalid changeset with errors routed to the
    correct fields (equivalent to calling `Zoi.parse/3` then
    `errors_to_changeset/1`).

    ## Examples

        iex> schema = Zoi.map(%{name: Zoi.string()})
        iex> changeset = Zoi.Ecto.changeset(schema, %{name: "Paulo"})
        iex> changeset.valid?
        true

        iex> schema = Zoi.map(%{name: Zoi.string()})
        iex> changeset = Zoi.Ecto.changeset(schema, %{name: 123})
        iex> changeset.valid?
        false
    """
    @spec changeset(struct(), map(), keyword()) :: Ecto.Changeset.t()
    def changeset(schema, input, opts \\ []) do
      case Zoi.parse(schema, input, opts) do
        {:ok, parsed} -> Ecto.Changeset.change({parsed, %{}})
        {:error, errors} -> errors_to_changeset(errors)
      end
    end

    @doc """
    Converts Zoi parse errors into an Ecto changeset.

    Returns a valid changeset when given an empty error list.
    Returns an invalid changeset with properly routed errors when given errors.

    ## Examples

        iex> schema = Zoi.map(%{name: Zoi.string()})
        iex> {:error, errors} = Zoi.parse(schema, %{name: 123})
        iex> changeset = Zoi.Ecto.errors_to_changeset(errors)
        iex> changeset.valid?
        false
    """
    @spec errors_to_changeset([Zoi.Error.t()]) :: Ecto.Changeset.t()
    def errors_to_changeset([]) do
      empty_changeset()
    end

    def errors_to_changeset(errors) when is_list(errors) do
      errors
      |> Enum.reduce(empty_changeset(), fn
        %Zoi.Error{code: code, issue: {template, issue_opts}, path: path}, cs ->
          ecto_opts = build_ecto_opts(code, template, issue_opts)
          route_error(cs, path, template, ecto_opts)
      end)
      |> to_ecto_array_changes()
      |> Map.put(:valid?, false)
    end

    defp build_ecto_opts(code, template, issue_opts) do
      base = Map.get(@code_mapping, code, [])

      base =
        if code in @size_codes do
          validation = resolve_size_validation(template)

          base
          |> Keyword.put(:validation, validation)
          |> remap_size_kind(validation)
        else
          base
        end

      validation = Keyword.get(base, :validation)

      issue_opts
      |> maybe_add_enum_list(code)
      |> maybe_add_number_key(validation)
      |> Kernel.++(base ++ [code: code])
    end

    # Ecto uses `enum: [list]` for inclusion errors.
    # Zoi provides `values: "a, b, c"` (comma-joined string) -- we split it
    # back into a list to match Ecto's format. This assumes enum values do
    # not contain ", " (comma-space). Pathological but documented.
    defp maybe_add_enum_list(issue_opts, :invalid_enum_value) do
      case Keyword.get(issue_opts, :values) do
        values when is_binary(values) ->
          enum = values |> String.split(", ") |> Enum.map(&String.trim/1)
          Keyword.put(issue_opts, :enum, enum)

        _ ->
          issue_opts
      end
    end

    defp maybe_add_enum_list(issue_opts, _code), do: issue_opts

    defp resolve_size_validation(template) do
      cond do
        String.ends_with?(template, "character(s)") -> :length
        String.ends_with?(template, "item(s)") -> :length
        true -> :number
      end
    end

    # Ecto uses :min/:max for length kind, not :greater_than_or_equal_to etc.
    @length_kind_map %{
      greater_than: :min,
      greater_than_or_equal_to: :min,
      less_than: :max,
      less_than_or_equal_to: :max
    }

    defp remap_size_kind(base, :length) do
      case Keyword.fetch(base, :kind) do
        {:ok, zoi_kind} -> Keyword.put(base, :kind, Map.get(@length_kind_map, zoi_kind, zoi_kind))
        :error -> base
      end
    end

    defp remap_size_kind(base, _validation), do: base

    # Ecto uses `number: target_value` for numeric validations.
    # Zoi provides `count: value` -- we add `number:` as Ecto expects.
    defp maybe_add_number_key(issue_opts, :number) do
      case Keyword.get(issue_opts, :count) do
        nil -> issue_opts
        count -> Keyword.put(issue_opts, :number, count)
      end
    end

    defp maybe_add_number_key(issue_opts, _validation), do: issue_opts

    # Root-level error (e.g., from Zoi.refine)
    defp route_error(cs, [], template, opts) do
      Ecto.Changeset.add_error(cs, :base, template, opts)
    end

    # Leaf field -- direct error on this changeset
    defp route_error(cs, [field], template, opts) when is_atom(field) do
      Ecto.Changeset.add_error(cs, field, template, opts)
    end

    # Nested map -- recurse into a child changeset
    defp route_error(cs, [field | rest], template, opts)
         when is_atom(field) and is_atom(hd(rest)) do
      child = Map.get(cs.changes, field, empty_changeset())

      updated =
        child
        |> route_error(rest, template, opts)
        |> Map.put(:valid?, false)

      %{cs | changes: Map.put(cs.changes, field, updated)}
    end

    # Array item -- route through an index-keyed map of child changesets
    defp route_error(cs, [field, index | rest], template, opts)
         when is_atom(field) and is_integer(index) do
      items = Map.get(cs.changes, field, %{})
      child = Map.get(items, index, empty_changeset())

      updated =
        child
        |> route_error(rest, template, opts)
        |> Map.put(:valid?, false)

      new_items = Map.put(items, index, updated)
      %{cs | changes: Map.put(cs.changes, field, new_items)}
    end

    # During routing, array items are stored as index-keyed maps for O(1)
    # lookup. After all errors are routed, convert to padded lists matching
    # Ecto's embeds_many convention: one changeset per array position.

    defp to_ecto_array_changes(%Ecto.Changeset{changes: changes} = cs) do
      updated =
        Map.new(changes, fn
          {field, %{} = index_map} when not is_struct(index_map) ->
            {field, index_map_to_list(index_map)}

          {field, %Ecto.Changeset{} = nested} ->
            {field, to_ecto_array_changes(nested)}

          other ->
            other
        end)

      %{cs | changes: updated}
    end

    defp index_map_to_list(index_map) do
      max_index = index_map |> Map.keys() |> Enum.max(fn -> -1 end)

      0..max_index
      |> Enum.map(fn i ->
        case Map.get(index_map, i) do
          nil -> empty_changeset()
          cs -> to_ecto_array_changes(cs)
        end
      end)
    end

    defp empty_changeset, do: Ecto.Changeset.change({%{}, %{}})
  end
end
