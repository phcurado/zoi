# Rendering forms with Phoenix

`Zoi` works seamlessly with Phoenix forms through the `Phoenix.HTML.FormData` protocol. This guide walks through building a complete LiveView form step by step.

## 1. Define Your Schema

First, define your validation schema inline using `Zoi.Form.prepare/1`:

```elixir
defmodule MyAppWeb.UserLive.FormComponent do
  use MyAppWeb, :live_view

  @user_schema Zoi.object(%{
    name: Zoi.string() |> Zoi.min(3),
    email: Zoi.email(),
    age: Zoi.integer() |> Zoi.min(18) |> Zoi.optional()
  }) |> Zoi.Form.prepare()
end
```

`Zoi.Form.prepare/1` enables automatic coercion so form strings convert to the right types (integers, booleans, etc.).

## 2. Parse and Render

Parse params with `Zoi.Form.parse/2` and convert the context to a Phoenix form:

```elixir
def mount(_params, _session, socket) do
  params = %{}  # Start with empty form
  ctx = Zoi.Form.parse(@user_schema, params)
  form = Phoenix.Component.to_form(ctx, as: :user)

  {:ok, assign(socket, form: form, ctx: ctx)}
end

def render(assigns) do
  ~H"""
  <.form for={@form} phx-change="validate" phx-submit="save">
    <.input field={@form[:name]} label="Name" />
    <.input field={@form[:email]} label="Email" />
    <.input field={@form[:age]} type="number" label="Age" />

    <div>
      <.button>Save</.button>
    </div>
  </.form>
  """
end
```

That's it! Phoenix's `<.input>` component automatically displays validation errors.

## 3. Handle Validation

Parse params on every change to show live validation:

```elixir
def handle_event("validate", %{"user" => params}, socket) do
  ctx = Zoi.Form.parse(@user_schema, params)
  form = Phoenix.Component.to_form(ctx, as: :user)

  {:noreply, assign(socket, form: form, ctx: ctx)}
end
```

## 4. Handle Submit

Check `ctx.valid?` and use `ctx.parsed` for validated data:

```elixir
def handle_event("save", %{"user" => params}, socket) do
  ctx = Zoi.Form.parse(@user_schema, params)

  if ctx.valid? do
    # ctx.parsed is validated and type-coerced
    # Example: %{name: "John", email: "john@example.com", age: 30}
    case Accounts.create_user(ctx.parsed) do
      {:ok, user} ->
        {:noreply, push_navigate(socket, to: ~p"/users/#{user}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save")}
    end
  else
    # Show all errors immediately on submit
    form = Phoenix.Component.to_form(ctx, as: :user, action: :validate)
    {:noreply, assign(socket, form: form, ctx: ctx)}
  end
end
```

## 5. Add Nested Arrays

Add nested addresses to your schema:

```elixir
@user_schema Zoi.object(%{
  name: Zoi.string() |> Zoi.min(3),
  email: Zoi.email(),
  addresses: Zoi.array(
    Zoi.object(%{
      street: Zoi.string() |> Zoi.min(5),
      city: Zoi.string(),
      zip: Zoi.string() |> Zoi.length(5)
    })
  )
}) |> Zoi.Form.prepare()
```

Render with `<.inputs_for>`:

```elixir
<.inputs_for :let={address} field={@form[:addresses]}>
  <div>
    <.input field={address[:street]} label="Street" />
    <.input field={address[:city]} label="City" />
    <.input field={address[:zip]} label="ZIP" />
  </div>
</.inputs_for>
```

## 6. Add Dynamic Add/Remove

Add and remove items directly from the context input. `Zoi.Form.parse/2` automatically normalizes array fields to lists:

```elixir
def handle_event("add_address", _params, socket) do
  # ctx.input has arrays already normalized to lists
  ctx = socket.assigns.ctx
  current_addresses = ctx.input["addresses"] || []
  updated_input = Map.put(ctx.input, "addresses", current_addresses ++ [%{}])

  new_ctx = Zoi.Form.parse(@user_schema, updated_input)
  form = Phoenix.Component.to_form(new_ctx, as: :user)

  {:noreply, assign(socket, form: form, ctx: new_ctx)}
end

def handle_event("remove_address", %{"index" => index}, socket) do
  idx = String.to_integer(index)
  ctx = socket.assigns.ctx
  current_addresses = ctx.input["addresses"] || []
  updated_input = Map.put(ctx.input, "addresses", List.delete_at(current_addresses, idx))

  new_ctx = Zoi.Form.parse(@user_schema, updated_input)
  form = Phoenix.Component.to_form(new_ctx, as: :user)

  {:noreply, assign(socket, form: form, ctx: new_ctx)}
end
```

In your template:

```elixir
<.button type="button" phx-click="add_address">Add Address</.button>

<.inputs_for :let={address} field={@form[:addresses]}>
  <div>
    <.input field={address[:street]} label="Street" />
    <.input field={address[:city]} label="City" />
    <.input field={address[:zip]} label="ZIP" />

    <.button type="button" phx-click="remove_address" phx-value-index={address.index}>
      Remove
    </.button>
  </div>
</.inputs_for>
```

## 7. Handle Create and Edit

Use `handle_params` to handle both `:new` and `:edit` actions:

```elixir
def handle_params(params, _url, socket) do
  {:noreply, apply_action(socket, socket.assigns.live_action, params)}
end

defp apply_action(socket, :new, _params) do
  params = %{"addresses" => [%{}]}  # Start with one empty address
  ctx = Zoi.Form.parse(@user_schema, params)
  form = Phoenix.Component.to_form(ctx, as: :user)

  socket
  |> assign(:page_title, "New User")
  |> assign(:user, nil)
  |> assign(:form, form)
  |> assign(:ctx, ctx)
end

defp apply_action(socket, :edit, %{"id" => id}) do
  user = Accounts.get_user!(id)

  # Convert database record to form params (all strings)
  params = %{
    "name" => user.name,
    "email" => user.email,
    "age" => user.age && to_string(user.age),
    "addresses" => Enum.map(user.addresses, fn addr ->
      %{
        "street" => addr.street,
        "city" => addr.city,
        "zip" => addr.zip
      }
    end)
  }

  ctx = Zoi.Form.parse(@user_schema, params)
  form = Phoenix.Component.to_form(ctx, as: :user)

  socket
  |> assign(:page_title, "Edit User")
  |> assign(:user, user)
  |> assign(:form, form)
  |> assign(:ctx, ctx)
end
```

Update save to dispatch based on action:

```elixir
def handle_event("save", %{"user" => params}, socket) do
  ctx = Zoi.Form.parse(@user_schema, params)

  if ctx.valid? do
    save_user(socket, socket.assigns.live_action, ctx.parsed)
  else
    form = Phoenix.Component.to_form(ctx, as: :user, action: :validate)
    {:noreply, assign(socket, form: form, ctx: ctx)}
  end
end

defp save_user(socket, :new, attrs) do
  case Accounts.create_user(attrs) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "User created")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to create")}
  end
end

defp save_user(socket, :edit, attrs) do
  case Accounts.update_user(socket.assigns.user, attrs) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "User updated")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update")}
  end
end
```
