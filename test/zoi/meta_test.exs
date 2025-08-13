defmodule Zoi.MetaTest do
  use ExUnit.Case, async: true

  alias Zoi.Types.Meta

  defmodule Validation do
    def integer?(_schema, value) when is_integer(value), do: :ok
    def integer?(_schema, _value), do: {:error, "Value is not an integer"}

    def upcase(_schema, value) when is_binary(value) do
      {:ok, String.upcase(value)}
    end

    def upcase(_schema, _value), do: {:error, "Value is not a string"}
  end

  describe "create_meta/1" do
    test "creates a meta struct with refinements and transforms" do
      opts = [
        refinements: [&is_integer/1],
        transforms: [&String.upcase/1],
        extra_param: "value"
      ]

      assert {%Meta{refinements: refinements, transforms: transforms}, rest} =
               Meta.create_meta(opts)

      assert refinements == [&is_integer/1]
      assert transforms == [&String.upcase/1]
      assert rest == [extra_param: "value"]
    end

    test "returns an empty meta struct when no options are provided" do
      {meta, rest} = Meta.create_meta([])

      assert %Meta{refinements: [], transforms: []} = meta
      assert rest == []
    end
  end

  describe "run_refinements/2" do
    test "runs refinements and returns ok for valid input" do
      schema = %Zoi.Types.Integer{
        meta: %Meta{
          refinements: [
            fn val ->
              if is_integer(val) do
                :ok
              else
                {:error, "Value is not an integer"}
              end
            end
          ]
        }
      }

      assert {:ok, 42} == Meta.run_refinements(schema, 42)
    end

    test "returns error for invalid input" do
      schema = %Zoi.Types.Integer{
        meta: %Meta{
          refinements: [
            fn _schema, val ->
              if is_integer(val) do
                :ok
              else
                {:error, "Value is not an integer"}
              end
            end
          ]
        }
      }

      assert {:error, [%Zoi.Error{} = errors]} = Meta.run_refinements(schema, "not an integer")
      assert Exception.message(errors) == "Value is not an integer"
    end

    test "refinement with mfa" do
      schema = %Zoi.Types.Integer{
        meta: %Meta{
          refinements: [{Validation, :integer?, []}]
        }
      }

      assert {:ok, 42} == Meta.run_refinements(schema, 42)
      assert {:error, [%Zoi.Error{} = errors]} = Meta.run_refinements(schema, "not an integer")
      assert Exception.message(errors) == "Value is not an integer"
    end

    test "accumulates errors from refinements" do
      schema = %Zoi.Types.String{
        meta: %Meta{
          refinements: [
            fn _schema, _val -> {:error, "refinement error 1"} end,
            fn _schema, _val -> {:error, "refinement error 2"} end
          ]
        }
      }

      assert {:error, [error_1, error_2]} = Meta.run_refinements(schema, "test")
      assert Exception.message(error_1) == "refinement error 1"
      assert Exception.message(error_2) == "refinement error 2"
    end
  end

  describe "run_transforms/2" do
    test "runs transforms and returns the transformed value" do
      schema = %Zoi.Types.String{
        meta: %Meta{
          transforms: [
            fn _schema, input -> String.trim(input) end,
            {Validation, :upcase, []}
          ]
        }
      }

      assert {:ok, "HELLO"} == Meta.run_transforms(schema, "  hello  ")
    end

    test "runs transforms and returns the tuple for valid input" do
      schema = %Zoi.Types.String{
        meta: %Meta{
          transforms: [fn _val -> {:ok, "random return"} end]
        }
      }

      assert {:ok, "random return"} == Meta.run_transforms(schema, "hello")
    end

    test "returns error for invalid transform" do
      schema = %Zoi.Types.String{
        meta: %Meta{
          transforms: [fn _schema, _val -> {:error, "Transform failed"} end]
        }
      }

      assert {:error, [%Zoi.Error{} = error]} = Meta.run_transforms(schema, "not a number")
      assert Exception.message(error) == "Transform failed"
    end

    test "returns error for invalid transform using mfa" do
      schema = %Zoi.Types.String{
        meta: %Meta{
          transforms: [{Validation, :upcase, []}]
        }
      }

      assert {:error, [%Zoi.Error{} = error]} = Meta.run_transforms(schema, 12)
      assert Exception.message(error) == "Value is not a string"
    end

    test "accumulates errors from transforms" do
      schema = %Zoi.Types.String{
        meta: %Meta{
          transforms: [
            fn _schema, _val ->
              {:error, "transform error 1"}
            end,
            fn _schema, _val ->
              {:error, "transform error 2"}
            end
          ]
        }
      }

      assert {:error, [error_1, error_2]} = Meta.run_transforms(schema, "test")
      assert Exception.message(error_1) == "transform error 1"
      assert Exception.message(error_2) == "transform error 2"
    end
  end
end
