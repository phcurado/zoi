# Validating controller parameters

One common use case for `Zoi` is validating request parameters in a Phoenix controller, before they reach your business logic or database layer.

Here's a typical controller setup using Ecto to validate the incoming params:

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  alias MyApp.Users

  def create(conn, params) do
    case Users.create_user(params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> render("show.json", user: user)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(MyAppWeb.ChangesetView, "error.json", changeset: changeset)
    end
  end
end
```

This works well when your API payload matches the database schema, but:

- You may want stricter or custom validation rules.
- Different field names than your schema.
- Your API shape may differ from your DB schema.
- You want to fail early, before calling your domain logic.
- Custom behaviour (optional fields, specific formats)

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  alias MyApp.Users

  @user_params Zoi.object(%{
    name: Zoi.string(),
    email: Zoi.email() |> Zoi.min(4) |> Zoi.max(100),
    age: Zoi.integer(coerce: true) |> Zoi.min(18) |> Zoi.max(100)
  })

  def create(conn, params) do
    case Zoi.parse(@user_params, params) do
      {:ok, valid_params} ->
        case Users.create_user(valid_params) do
          {:ok, user} ->
            conn
            |> put_status(:created)
            |> render("show.json", user: user)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(MyAppWeb.ChangesetView, "error.json", changeset: changeset)
        end

      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(MyAppWeb.ErrorView, "error.json", errors: Zoi.treefy_errors(errors))
    end
  end
end
```

- `Zoi.parse/2` returns `{:ok, data}` or `{:error, [Zoi.Error.t()]}`.
- `Zoi.treefy_errors/1` transforms flat error lists into a structured tree, useful for forms or APIs.

## Validating query parameters

One powerful use case for `Zoi` is validating and normalizing query parameters passed to your Phoenix controller.

Imagine a paginated endpoint like this:

`GET /api/posts?page=2&limit=50&sort=-published_at`

possible validations:

- Ensure page and limit are integers
- Apply default values if not provided
- Validate sort against allowed fields

```elixir
@query_schema Zoi.object(%{
  page: Zoi.default(Zoi.integer(coerce: true) |> Zoi.min(1), 1),
  limit: Zoi.default(Zoi.integer(coerce: true) |> Zoi.min(1) |> Zoi.max(100), 10),
  sort: Zoi.optional(Zoi.string() |> Zoi.enum(["published_at", "-published_at"]))
})
```

Use it on your controller:

```elixir
def index(conn, params) do
  case Zoi.parse(@query_schema, params) do
    {:ok, query} ->
      posts = Blog.list_posts(query)
      render(conn, "index.json", posts: posts)

    {:error, errors} ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: Zoi.treefy_errors(errors)})
  end
end
```

And sending invalid params: `GET /api/posts?page=0&limit=200&sort=name`
will return a structured error response like this:

```json
{
  "errors": {
    "page": ["too small: must be at least 1"],
    "limit": ["too big: must be at most 100"],
    "sort": ["Invalid option: must be one of published_at, -published_at"]
  }
}
```

This approach allows you to:
