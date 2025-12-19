defmodule Zoi.Describe do
  @moduledoc """
  `Zoi.describe/1` introspect schemas, finding it's `:description` metadata and type specifications to generate documentation strings.
  This documentation that can be used in HexDocs or other places where you want to describe the options your schema accepts.

  This module was inspired by [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html), which can also generate documentation for options.

  ## Usage

  To generate descriptions, you just need to call `Zoi.describe/1` for the `Zoi.keyword/2` or `Zoi.object/2` schema.

      defmodule MyApp.Config do
        @schema Zoi.keyword([
          host: Zoi.string(description: "The host of the server.") |> Zoi.required(),
          port: Zoi.integer(description: "The port of the server.") |> Zoi.default(8080),
          debug: Zoi.boolean(description: "Enable debug mode.")
        ])

        @moduledoc \"""
        Configuration for MyApp.

        \#{Zoi.describe(@schema)}
        \"""
      end

  The generated documentation will look like this:

  * `:host` (`t:String.t/0`) - Required. The host of the server.

  * `:port` (`t:integer/0`) - Required. The port of the server. The default value is `8080`.

  * `:debug` (`t:boolean/0`) - Enable debug mode.

  All `Zoi` types are supported, and you can leverage the type specifications and documentation metadata to produce comprehensive docs for your schemas. 

  A common use case is documenting `opts` parameters for functions that accept keyword lists, where you can define the expected options using `Zoi.keyword/2` and generate the corresponding documentation automatically, for example:

      @list_user_opts Zoi.keyword([
        active: Zoi.boolean(description: "Whether the feature is active.") |> Zoi.default(true),
        group: Zoi.string(description: "The group name.")
      ])
      @type list_user_opts :: unquote(Zoi.type_spec(@list_user_opts))

      @doc \"""
      List  users.

      Options:
      \#{Zoi.describe(@list_user_opts)}
      \"""
      @spec list_users(opts :: list_user_opts()) :: [User.t()]
      def list_users(opts \\\\ []) do
        opts = Zoi.parse!(@list_user_opts, opts)

        User
        |> where(active: opts[:active])
        |> where(group: opts[:group])
        |> Repo.all()
      end


  Which would be translated to:
      @type list_user_opts :: [active: boolean(), group: binaryt()]

      @doc \"""
      List  users.

      Options:
      * `:active` (`t:boolean/0`) - The feature is active. The default value is `true`.
      * `:group` (`t:String.t/0`) - The group name.
      \"""
      @spec list_users(opts :: list_user_opts()) :: [User.t()]
      def list_users(opts \\\\ []) do
        # ...
      end

  The same pattern will work for `Zoi.object/2` and `Zoi.struct/3` schemas as well, since you may also use them to define a structured map input.

      schema = Zoi.object(%{
        name: Zoi.email(description: "The email address."), 
        role: Zoi.enum([admin: "Admin", user: "User"], description: "The role of the user." )
      })
      Zoi.describe(schema)

  Which would produce:

  * `:name` (`t:String.t/0`) - Required. The email address.
  * `:role` (one of `"Admin"`, `"User"`) - Required. The role of the user.
  """

  alias Zoi.Describe.Encoder
  alias Zoi.Types.Meta

  @doc false
  @spec generate(Zoi.schema()) :: binary()
  def generate(%Zoi.Types.Keyword{fields: fields}) do
    Enum.map_join(fields, "\n\n", &parse_field/1) <> "\n"
  end

  def generate(%Zoi.Types.Object{fields: fields}) do
    Enum.map_join(fields, "\n\n", &parse_field/1) <> "\n"
  end

  def generate(%Zoi.Types.Struct{fields: fields}) do
    Enum.map_join(fields, "\n\n", &parse_field/1) <> "\n"
  end

  def generate(_schema) do
    raise ArgumentError,
          "Zoi.describe/1 only supports describing keyword, object and struct schemas"
  end

  defp parse_field({key, schema}) do
    "* `:#{key}` (#{Encoder.encode(schema)})#{parse_value(schema)}"
  end

  defp parse_value(schema) do
    prefix = " - "

    description =
      schema
      |> check_required()
      |> check_description(schema)

    if description == "" do
      description
    else
      prefix <> description
    end
  end

  defp check_required(schema) do
    if Meta.required?(schema.meta) do
      "Required. "
    else
      ""
    end
  end

  defp check_description(str, %Zoi.Types.Default{inner: inner, value: value}) do
    check_description(str, inner) <> " The default value is `#{inspect(value)}`."
  end

  defp check_description(str, schema) do
    case schema.meta.description do
      nil -> str
      description -> str <> description
    end
  end
end
