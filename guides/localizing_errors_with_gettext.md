# Localizing Zoi errors with Gettext

`Zoi.Error` already stores two versions of every message:

- `message`: rendered string (good for logging)
- `issue`: `{template, keyword}` tuple (perfect for translation)

This guide shows how to use that data with `Gettext`, including a `.pot` template you can drop
into your project.

## 1. Extract error messages

Whenever you define custom errors, prefer the `issue` tuple to keep interpolation markers:

```elixir
schema =
  Zoi.string()
  |> Zoi.refine(fn value ->
    if String.length(value) < 3 do
      {:error, {"too short", []}}
    else
      :ok
    end
  end)
```

Built-in errors already come with templates such as
`{"invalid type: expected %{type}", [type: :string]}`.

## 2. Build a translation helper

Transform Zoi errors into translated strings by passing the template to `Gettext.dgettext/4`.

```elixir
defmodule MyAppWeb.ErrorTranslator do
  import MyAppWeb.Gettext

  def translate_error(%Zoi.Error{issue: {msg, opts}}) when is_binary(msg) do
    dgettext("zoi", msg, Map.new(opts))
  end

  def translate_error(%Zoi.Error{message: message}), do: message

  def translate_errors(errors) do
    Enum.map(errors, &translate_error/1)
  end
end
```

Now your controllers or LiveViews can return localized payloads:

```elixir
with {:error, errors} <- Zoi.parse(schema, params) do
  render(conn, :error, errors: MyAppWeb.ErrorTranslator.translate_errors(errors))
end
```

## 3. Sample `zoi.pot`

Create `priv/gettext/zoi.pot` (or run `mix gettext.extract` after adding references) with
entries for the messages you care about:

```
msgid ""
msgstr ""
"Language: en\n"
"Plural-Forms: nplurals=2; plural=(n != 1);\n"

#: lib/my_app/accounts/user_schema.ex:12
msgid "invalid type: expected %{type}"
msgstr ""

#: lib/my_app/accounts/user_schema.ex:34
msgid "too small: must have at least %{count} character(s)"
msgstr ""

#: lib/my_app/accounts/user_schema.ex:40
msgid "unrecognized key: '%{key}'"
msgstr ""
```

After running `mix gettext.merge priv/gettext`, you will get locale-specific `.po` files
(`priv/gettext/es/LC_MESSAGES/zoi.po`, etc.) where you can provide translations:

```
msgid "invalid type: expected %{type}"
msgstr "tipo inválido: era esperado %{type}"
```

## 4. Wiring it to Phoenix forms

When turning the context into a form, plug the translated errors into `form.errors`:

```elixir
context = Zoi.Form.parse(schema, params)
form = Phoenix.Component.to_form(context, as: :user)

translated =
  Enum.map(form.errors, fn {field, {msg, opts}} ->
    {field, dgettext("zoi", msg, Map.new(opts))}
  end)

assign(socket, form: %{form | errors: translated})
```

Because Zoi always keeps the `issue` tuple, you control how and when translations happen—
wearing minimal glue code and keeping your schema definitions clean.
