if Code.ensure_loaded?(Ecto) do
  defmodule Zoi.Ecto do
    @moduledoc """
    Generate Ecto embedded schemas from Zoi schemas.

    This module allows you to define your schema once with Zoi and derive an Ecto embedded schema from it. 
    This way Zoi is the single source of truth for fields, types, and validations, while Ecto provides the struct and changeset interface that downstream tools (Phoenix forms, Absinthe, etc.) expect.

    ## Usage

        defmodule MyApp.UserInput do
          require Zoi.Ecto

          @schema Zoi.map(%{
            name: Zoi.string(),
            age: Zoi.integer(),
            email: Zoi.email()
          })

          Zoi.Ecto.generate_embedded_schema(@schema)

          def schema, do: @schema
        end

    This generates an `embedded_schema` with the appropriate Ecto field types.

    ## Nested schemas

    Nested `Zoi.map` fields become inline Ecto embeds:

        @schema Zoi.map(%{
          name: Zoi.string(),
          address: Zoi.map(%{
            street: Zoi.string(),
            number: Zoi.integer()
          })
        })

    Generates the equivalent of:

        embedded_schema do
          field :name, :string
          embeds_one :address do
            field :street, :string
            field :number, :integer
          end
        end
    """

    defmacro generate_embedded_schema(schema) do
      quote do
        Module.put_attribute(__MODULE__, :__zoi_ecto_schema__, unquote(schema))
        @before_compile Zoi.Ecto
      end
    end

    @doc false
    defmacro __before_compile__(env) do
      schema = Module.get_attribute(env.module, :__zoi_ecto_schema__)
      fields_ast = build_fields_ast(schema)
      escaped_schema = Macro.escape(schema)

      quote do
        use Ecto.Schema

        @primary_key false
        embedded_schema do
          (unquote_splicing(fields_ast))
        end

        @doc "Returns the Zoi schema used to generate this embedded schema."
        def __zoi_schema__, do: unquote(escaped_schema)
      end
    end

    @doc false
    def build_fields_ast(%Zoi.Types.Map{fields: fields}) do
      Enum.map(fields, fn {key, type} ->
        do_build_field_ast(key, type)
      end)
    end

    defp do_build_field_ast(key, %Zoi.Types.Map{fields: fields} = schema) when is_list(fields) do
      inner_ast = build_fields_ast(schema)

      quote do
        embeds_one unquote(key), unquote(embed_module_name(key)) do
          (unquote_splicing(inner_ast))
        end
      end
    end

    defp do_build_field_ast(name, %Zoi.Types.Array{
           inner: %Zoi.Types.Map{fields: fields} = map_schema
         })
         when is_list(fields) do
      inner_ast = build_fields_ast(map_schema)

      quote do
        embeds_many unquote(name), unquote(embed_module_name(name)) do
          (unquote_splicing(inner_ast))
        end
      end
    end

    defp do_build_field_ast(name, %Zoi.Types.Default{inner: inner, value: value}) do
      ecto_type = to_ecto_type(inner)

      quote do
        field unquote(name), unquote(ecto_type), default: unquote(value)
      end
    end

    defp do_build_field_ast(name, %Zoi.Types.Enum{enum_type: :atom, values: values}) do
      keys = Keyword.keys(values)

      quote do
        field unquote(name), Ecto.Enum, values: unquote(keys)
      end
    end

    defp do_build_field_ast(name, %Zoi.Types.Enum{enum_type: :integer}) do
      quote do
        field unquote(name), :integer
      end
    end

    defp do_build_field_ast(name, %Zoi.Types.Enum{}) do
      quote do
        field unquote(name), :string
      end
    end

    defp do_build_field_ast(name, type) do
      ecto_type = to_ecto_type(type)

      quote do
        field unquote(name), unquote(ecto_type)
      end
    end

    defp to_ecto_type(%Zoi.Types.Union{schemas: [%Zoi.Types.Null{}, inner]}) do
      to_ecto_type(inner)
    end

    defp to_ecto_type(%Zoi.Types.String{}), do: :string
    defp to_ecto_type(%Zoi.Types.Integer{}), do: :integer
    defp to_ecto_type(%Zoi.Types.Float{}), do: :float
    defp to_ecto_type(%Zoi.Types.Boolean{}), do: :boolean
    defp to_ecto_type(%Zoi.Types.Date{}), do: :date
    defp to_ecto_type(%Zoi.Types.Time{}), do: :time
    defp to_ecto_type(%Zoi.Types.DateTime{}), do: :utc_datetime
    defp to_ecto_type(%Zoi.Types.NaiveDateTime{}), do: :naive_datetime
    defp to_ecto_type(%Zoi.Types.Decimal{}), do: :decimal
    defp to_ecto_type(%Zoi.Types.Literal{value: value}) when is_binary(value), do: :string
    defp to_ecto_type(%Zoi.Types.Literal{value: value}) when is_integer(value), do: :integer
    defp to_ecto_type(%Zoi.Types.Literal{value: value}) when is_float(value), do: :float
    defp to_ecto_type(%Zoi.Types.Literal{value: value}) when is_boolean(value), do: :boolean
    defp to_ecto_type(%Zoi.Types.Literal{value: value}) when is_atom(value), do: :string

    defp to_ecto_type(%Zoi.Types.Array{inner: inner}) do
      {:array, to_ecto_type(inner)}
    end

    defp to_ecto_type(%Zoi.Types.Map{fields: nil}), do: :map
    defp to_ecto_type(%Zoi.Types.Map{fields: []}), do: :map
    defp to_ecto_type(_type), do: :map

    defp embed_module_name(name) do
      name
      |> Atom.to_string()
      |> Macro.camelize()
      |> String.to_atom()
    end

    ## Changeset

    def changeset(%module{} = struct, params) do
      do_changeset(struct, module, params)
    end

    def do_changeset(struct, module, params) do
      schema = module.__zoi_schema__()
      ctx = Zoi.Context.new(schema, params) |> Zoi.Context.parse()

      changeset = Ecto.Changeset.change(struct, ctx.parsed || %{})

      case ctx do
        %{valid?: true} ->
          changeset

        %{valid?: false, errors: errors} ->
          changeset
          |> add_errors(errors)
          |> Map.put(:valid?, false)
      end
    end

    defp add_errors(changeset, errors) do
      Enum.reduce(errors, changeset, fn %Zoi.Error{} = error, cs ->
        put_error(cs, error.path, error.message, error.code)
      end)
    end

    defp put_error(cs, [], message, code) do
      Ecto.Changeset.add_error(cs, :base, message, code: code)
    end

    defp put_error(cs, [field], message, code) do
      Ecto.Changeset.add_error(cs, field, message, code: code)
    end

    defp put_error(cs, [field | rest], message, code) do
      embed_cs = cs.changes[field]
      updated = put_error(embed_cs, rest, message, code) |> Map.put(:valid?, false)
      %{cs | changes: Map.put(cs.changes, field, updated)}
    end
  end
end
