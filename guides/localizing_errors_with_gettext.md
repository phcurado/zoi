# Localizing Zoi errors with Gettext

`Zoi.Error` already stores two versions of every message:

- `message`: rendered string (good for logging)
- `issue`: `{template, keyword}` tuple (perfect for translation)

This guide shows how to use that data with `Gettext`, including a `.pot` template you can drop into your project.

## 1. Extract error messages

Whenever you define custom errors, prefer the `issue` tuple to keep interpolation markers:

```elixir
schema =
  Zoi.string()
  |> Zoi.refine(fn value ->
    if String.length(value) < 3 do
      {:error, {"too short, should be smaller than %{count}", [count: 3]}}
    else
      :ok
    end
  end)
```

`Zoi` will automatically build the `message` string by replacing `%{count}` with `3`. This way, you can leverage dynamic values in your error messages.
This aligns with how `Gettext` handles error translations.
For example, the built-in `Zoi.min/2` validator uses:

```elixir
{"too small: must have at least %{count} character(s)", [count: min]}
```

Let's use these built-in messages as examples for localization.

## 2. Build a translation helper

Phoenix's `<.input>` component already translates errors automatically if you provide a `translate_error/1` function in your `CoreComponents` module:

```elixir
defmodule MyAppWeb.CoreComponents do
  # ... Components

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # Because error messages are generated dynamically, we need to
    # call Gettext with our backend as first argument. Translations
    # are available in the errors.po file (using the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(MyAppWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MyAppWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates all errors for a field from a keyword list.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
```

So no changes are required in your phoenix application. If you are not using Phoenix, create a similar helper function to translate errors using `Gettext`.

## 3. Add error messages to your `.pot` file

Add the following entries to `priv/gettext/errors.pot` (or create it) to cover built-in Zoi errors.

**Important**: The template strings must match **exactly** as Zoi generates them. Here are the most common ones:

```pot
## Required field errors
msgid "is required"
msgstr ""

## String validation errors
msgid "too small: must have at least %{count} character(s)"
msgid_plural "too small: must have at least %{count} character(s)"
msgstr[0] ""
msgstr[1] ""

msgid "too big: must have at most %{count} character(s)"
msgid_plural "too big: must have at most %{count} character(s)"
msgstr[0] ""
msgstr[1] ""

msgid "invalid length: must have %{count} character(s)"
msgid_plural "invalid length: must have %{count} character(s)"
msgstr[0] ""
msgstr[1] ""

msgid "invalid email format"
msgstr ""

## Integer/Number validation errors
msgid "too small: must be at least %{count}"
msgid_plural "too small: must be at least %{count}"
msgstr[0] ""
msgstr[1] ""

msgid "too big: must be at most %{count}"
msgid_plural "too big: must be at most %{count}"
msgstr[0] ""
msgstr[1] ""

msgid "too small: must be greater than %{count}"
msgid_plural "too small: must be greater than %{count}"
msgstr[0] ""
msgstr[1] ""

msgid "too big: must be less than %{count}"
msgid_plural "too big: must be less than %{count}"
msgstr[0] ""
msgstr[1] ""

## Type errors
msgid "invalid type: expected string"
msgstr ""

msgid "invalid type: expected integer"
msgstr ""

msgid "invalid type: expected boolean"
msgstr ""

msgid "invalid type: expected number"
msgstr ""

msgid "invalid type: expected array"
msgstr ""

## Format/Pattern errors
msgid "invalid format: must be a valid URL"
msgstr ""

msgid "invalid UUID format"
msgstr ""

## Other common type errors (add as needed)
# msgid "invalid type: expected date"
# msgid "invalid type: expected datetime"
# msgid "unrecognized key: %{key}"
```

## 4. Extract and translate

Run the extraction command to propagate entries to your locale files:

```bash
mix gettext.extract --merge
```

This creates/updates files like `priv/gettext/pt_BR/LC_MESSAGES/errors.po`. Edit those files to add translations:

```po
# priv/gettext/pt_BR/LC_MESSAGES/errors.po
msgid "is required"
msgstr "campo obrigatório"

msgid "invalid email format"
msgstr "formato de email inválido"

msgid "too small: must have at least %{count} character(s)"
msgid_plural "too small: must have at least %{count} character(s)"
msgstr[0] "muito curto: deve ter pelo menos %{count} caractere"
msgstr[1] "muito curto: deve ter pelo menos %{count} caracteres"
```

**Tip**: Focus on translating the errors your application actually uses. You don't need to translate every possible `Zoi` error upfront.
