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
    test "creates a meta struct with validations and transforms" do
      opts = [
        validations: [{:refine, &is_integer/1}],
        transforms: [&String.upcase/1],
        extra_param: "value"
      ]

      assert {%Meta{validations: validations, transforms: transforms}, rest} =
               Meta.create_meta(opts)

      assert validations == [{:refine, &is_integer/1}]
      assert transforms == [&String.upcase/1]
      assert rest == [extra_param: "value"]
    end

    test "returns an empty meta struct when no options are provided" do
      {meta, rest} = Meta.create_meta([])

      assert %Meta{validations: [], transforms: []} = meta
      assert rest == []
    end
  end

  describe "run_validations/2" do
    test "runs validations and returns ok for valid input" do
      schema = %Zoi.Types.Integer{
        meta: %Meta{
          validations: [
            {:refine,
             fn _schema, val, _opts ->
               if is_integer(val) do
                 :ok
               else
                 {:error, "Value is not an integer"}
               end
             end, []}
          ]
        }
      }

      assert {:ok, 42} == Meta.run_validations(schema, 42)
    end

    test "returns error for invalid input" do
      schema = %Zoi.Types.Integer{
        meta: %Meta{
          validations: [
            {:refine,
             fn _schema, val, _opts ->
               if is_integer(val) do
                 :ok
               else
                 {:error, "Value is not an integer"}
               end
             end, []}
          ]
        }
      }

      assert {:error, _} = Meta.run_validations(schema, "not an integer")
    end

    test "validation with mfa" do
      schema = %Zoi.Types.Integer{
        meta: %Meta{
          validations: [{Validation, :integer?, []}]
        }
      }

      assert {:ok, 42} == Meta.run_validations(schema, 42)
      assert {:error, _} = Meta.run_validations(schema, "not an integer")
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
          transforms: [fn _schema, _val -> {:ok, "random return"} end]
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

      assert {:error, "Transform failed"} == Meta.run_transforms(schema, "not a number")
    end

    test "returns error for invalid transform using mfa" do
      schema = %Zoi.Types.String{
        meta: %Meta{
          transforms: [{Validation, :upcase, []}]
        }
      }

      assert {:error, "Value is not a string"} == Meta.run_transforms(schema, 12)
    end
  end
end
