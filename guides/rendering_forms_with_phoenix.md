# Rendering forms with Phoenix

`Zoi` ships with a `Phoenix.HTML.FormData` implementation, which means a `%Zoi.Context{}` can
be passed straight into `Phoenix.Component.to_form/2` (and the rest of the Phoenix HTML/HEEx
form helpers). This guide walks through a realistic setup that accepts nested data, keeps the submitted values on
validation errors, and performs coercion automatically (strings from the browser become the
expected type).

## 1. Build a form-friendly schema

Wrap your object schema with `Zoi.Form.enhance/1` so every field coerces string params and
`nil`/`""` counts as empty input.

```elixir
defmodule MyAppWeb.AccountForm do
  @user_schema
    Zoi.object(%{
      profile: Zoi.object(%{
        name: Zoi.string() |> Zoi.min(3),
        birth_year: Zoi.integer() |> Zoi.min(1900),
        marketing_opt_in: Zoi.boolean() |> Zoi.optional()
      }),
      addresses:
        Zoi.array(
          Zoi.object(%{
            label: Zoi.string(),
            street: Zoi.string() |> Zoi.min(5),
            zip: Zoi.integer()
          })
        )
    })
    |> Zoi.Form.enhance()

  def schema, do: @user_schema
end
```

Because the schema is declarative, you get nested validation, coercion, transforms, and
refinements across the entire data structure.

## 2. Parse params and convert to a Phoenix form

Inside your controller or LiveView, call `Zoi.Form.parse/3` and send the resulting context to
`Phoenix.Component.to_form/2`. The context stores both `input` (raw params) and `parsed`
(successfully validated data), so fields re-render with whatever the user typed.

```elixir
def edit(assigns) do
  context =
    assigns.params
    |> Zoi.Form.parse(MyAppWeb.AccountForm.schema())

  assigns = assign(assigns, :form, Phoenix.Component.to_form(context, as: :user))

  ~H"""
  <.form for={@form} phx-submit="save">
    <.inputs_for :let={profile} field={@form[:profile]}>
      <.input field={profile[:name]} label="Name" />
      <.input field={profile[:birth_year]} type="number" label="Birth year" />
      <.input field={profile[:marketing_opt_in]} type="checkbox" label="Updates?" />
    </.inputs_for>

    <.inputs_for :let={address} field={@form[:addresses]}>
      <div class="address">
        <.input field={address[:label]} label="Label" />
        <.input field={address[:street]} label="Street" />
        <.input field={address[:zip]} type="number" label="ZIP code" />
      </div>
    </.inputs_for>

    <button type="submit">Save</button>
  </.form>
  """
end
```

## 3. Nested data stays simple

Every time you call `Zoi.Form.parse/3` you get:

- Validation errors mapped to the appropriate path (e.g., `[:addresses, 1, :zip]`).
- Dynamic collections rendered through `inputs_for` without writing custom traversal logic.
- Partial results kept in `context.parsed`. If the second address fails, the first stays parsed
  and available in `form.data`.

This keeps the form pipeline small: define a schema and reuse it everywhere—controllers,
LiveViews, background jobs, etc. There is no need to mirror validations across multiple layers
or maintain placeholder structs; the schema is the source of truth.

## 4. Handling submit results

Since `Zoi.Form.parse/3` returns the context, checking `context.valid?` tells you whether all
fields passed.

```elixir
case Zoi.Form.parse(MyAppWeb.AccountForm.schema(), params) do
  %Zoi.Context{valid?: true, parsed: attrs} ->
    Accounts.save_user(attrs)

  %Zoi.Context{} = ctx ->
    {:error, Phoenix.Component.to_form(ctx, as: :user)}
end
```

Re-rendering is just a matter of reusing the same context, so no data is lost between
submissions.
