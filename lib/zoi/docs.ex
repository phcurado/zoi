defmodule Zoi.Docs do
  @moduledoc """
  Module for generating documentation for `Zoi` types.
  Using `Zoi` metadata, you can produce documentation that can be used in HexDocs.

  This module was inspired by [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html), which can also generate documentation for options.

  ## Usage

  To generate docs, you just need to call `Zoi.docs/1` for the `Zoi.keyword/2` or `Zoi.object/2` schema.

      defmodule MyApp.Config do
        @schema Zoi.keyword([
          host: Zoi.string(doc: "The host of the server.") |> Zoi.required(),
          port: Zoi.integer(doc: "The port of the server.") |> Zoi.default(8080),
          debug: Zoi.boolean(doc: "Enable debug mode.")
        ])

        @moduledoc \"""
        Configuration for MyApp.

        \#{Zoi.docs(@schema)}
        \"""
      end

  The generated documentation will look like this:

  * `:host` (`t:String.t/0`) - Required. The host of the server.

  * `:port` (`t:integer/0`) - Required. The port of the server. The default value is `8080`.

  * `:debug` (`t:boolean/0`) - Enable debug mode.

  All `Zoi` types are supported, and you can leverate the type specifications and documentation metadata to produce comprehensive docs for your schemas. 
  A common use case is documenting `opts` parameters for functions that accept keyword lists, where you can define the expected options using `Zoi.keyword/2` and generate the corresponding documentation automatically, for example:

      @list_user_opts Zoi.keyword([
        active: Zoi.boolean(doc: "Whether the feature is active.") |> Zoi.default(true),
        group: Zoi.string(doc: "The group name.")
      ])
      @type list_user_opts :: unquote(Zoi.type_spec(@list_user_opts))

      @doc \"""
      List  users.

      Options:
      \#{Zoi.docs(@list_user_opts)}
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
  """

  alias Zoi.Types.Meta

  @doc false
  @spec generate(Zoi.Type.t()) :: binary()
  def generate(%Zoi.Types.Keyword{fields: fields}) do
    Enum.map_join(fields, "\n\n", &parse_field/1) <> "\n"
  end

  def generate(%Zoi.Types.Object{fields: fields}) do
    Enum.map_join(fields, "\n\n", &parse_field/1) <> "\n"
  end

  defp parse_field({key, schema}) do
    "* `:#{key}` (#{parse_type_spec(schema)})#{parse_value(schema)}"
  end

  defp parse_type_spec(%Zoi.Types.Any{}), do: "`t:term/0`"
  defp parse_type_spec(%Zoi.Types.Array{inner: inner}), do: "list of #{parse_type_spec(inner)}"
  defp parse_type_spec(%Zoi.Types.Atom{}), do: "`t:atom/0`"
  defp parse_type_spec(%Zoi.Types.Boolean{}), do: "`t:boolean/0`"
  defp parse_type_spec(%Zoi.Types.Date{}), do: "`t:Date.t/0`"
  defp parse_type_spec(%Zoi.Types.DateTime{}), do: "`t:DateTime.t/0`"
  defp parse_type_spec(%Zoi.Types.Decimal{}), do: "`t:Decimal.t/0`"
  defp parse_type_spec(%Zoi.Types.Default{inner: inner}), do: parse_type_spec(inner)

  defp parse_type_spec(%Zoi.Types.Enum{values: values}),
    do: "one of #{Enum.map_join(values, ", ", fn {_key, value} -> parse_enum_spec(value) end)}"

  defp parse_type_spec(%Zoi.Types.Float{}), do: "`t:float/0`"
  defp parse_type_spec(%Zoi.Types.Integer{}), do: "`t:integer/0`"

  defp parse_type_spec(%Zoi.Types.Intersection{schemas: schemas}) do
    Enum.map_join(schemas, " and ", &parse_type_spec/1)
  end

  defp parse_type_spec(%Zoi.Types.Keyword{}), do: "`t:keyword/0`"
  defp parse_type_spec(%Zoi.Types.Literal{value: value}), do: "`#{inspect(value)}`"
  defp parse_type_spec(%Zoi.Types.Map{}), do: "`t:map/0`"
  defp parse_type_spec(%Zoi.Types.NaiveDateTime{}), do: "`t:NaiveDateTime.t/0`"
  defp parse_type_spec(%Zoi.Types.Null{}), do: "`nil`"
  defp parse_type_spec(%Zoi.Types.Number{}), do: "`t:number/0`"
  defp parse_type_spec(%Zoi.Types.Object{}), do: "`t:map/0`"
  defp parse_type_spec(%Zoi.Types.String{}), do: "`t:String.t/0`"
  defp parse_type_spec(%Zoi.Types.StringBoolean{}), do: "`t:boolean/0` or `t:String.t/0`"

  defp parse_type_spec(%Zoi.Types.Struct{module: module}),
    do: "struct of type `#{inspect(module)}`"

  defp parse_type_spec(%Zoi.Types.Time{}), do: "`t:Time.t/0`"

  defp parse_type_spec(%Zoi.Types.Tuple{fields: fields}) do
    field_types = Enum.map_join(fields, ", ", &parse_type_spec/1)
    "tuple of #{field_types} values"
  end

  defp parse_type_spec(%Zoi.Types.Union{schemas: schemas}) do
    Enum.map_join(schemas, " or ", &parse_type_spec/1)
  end

  defp parse_enum_spec(value) when is_atom(value), do: "`:#{value}`"
  defp parse_enum_spec(value), do: "#{value}"

  defp parse_value(schema) do
    prefix = " - "

    doc =
      schema
      |> check_required()
      |> check_doc(schema)

    if doc == "" do
      doc
    else
      prefix <> doc
    end
  end

  defp check_required(schema) do
    if Meta.required?(schema.meta) do
      "Required. "
    else
      ""
    end
  end

  defp check_doc(str, %Zoi.Types.Default{inner: inner, value: value}) do
    check_doc(str, inner) <> " The default value is `#{inspect(value)}`."
  end

  defp check_doc(str, schema) do
    case Zoi.doc(schema) do
      nil -> str
      doc -> str <> doc
    end
  end
end
