defmodule Zoi.MetaTest do
  use ExUnit.Case, async: true

  alias Zoi.Types.Meta

  defmodule Validation do
    def integer?(input, _opts) when is_integer(input), do: :ok
    def integer?(_input, _opts), do: {:error, "Value is not an integer"}

    def integer_error?(_input, opts) do
      opts[:ctx]
      |> Zoi.Context.add_error(%{message: "Value is not an integer", path: [:test]})
    end

    def upcase(value, _opts) when is_binary(value) do
      {:ok, String.upcase(value)}
    end

    def upcase(_value, _opts), do: {:error, "Value is not a string"}

    def upcase_error(_value, opts) do
      opts[:ctx]
      |> Zoi.Context.add_error(%{message: "Value is not a string"})
    end
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

  describe "run_refinements/1" do
    test "runs refinements and returns ok for valid input" do
      schema =
        Zoi.integer()
        |> Zoi.refine(fn val ->
          if val > 10 do
            :ok
          else
            {:error, "Value is smaller or equal to 10"}
          end
        end)

      input = 42

      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)

      assert {:ok, 42} == Meta.run_refinements(ctx)

      assert {:error, [%Zoi.Error{} = error]} =
               Meta.run_refinements(Zoi.Context.add_parsed(ctx, 9))

      assert Exception.message(error) == "Value is smaller or equal to 10"
    end

    test "refinement with mfa" do
      schema = Zoi.integer() |> Zoi.refine({Validation, :integer?, []})

      input = 42
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)
      assert {:ok, 42} == Meta.run_refinements(ctx)

      assert {:error, [%Zoi.Error{} = error]} =
               Meta.run_refinements(Zoi.Context.add_parsed(ctx, "55"))

      assert Exception.message(error) == "Value is not an integer"
    end

    test "accumulates errors from refinements" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _val -> {:error, "refinement error 1"} end)
        |> Zoi.refine(fn _val -> {:error, "refinement error 2"} end)

      input = "test"
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)

      assert {:error, [error_1, error_2]} = Meta.run_refinements(ctx)

      assert Exception.message(error_1) == "refinement error 1"
      assert Exception.message(error_2) == "refinement error 2"
    end

    test "return multiple errors from a single refinement" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _val, ctx ->
          Zoi.Context.add_error(ctx, %{message: "refinement error 1", path: [:test]})
          |> Zoi.Context.add_error("refinement error 2")
        end)

      input = "test"
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)

      assert {:error, [error_1, error_2]} = Meta.run_refinements(ctx)

      assert Exception.message(error_1) == "refinement error 1"
      assert Exception.message(error_2) == "refinement error 2"
    end

    test "return multiple errors from a refinement with mfa" do
      schema = Zoi.string() |> Zoi.refine({Validation, :integer_error?, []})

      input = "not an integer"
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)

      assert {:error, [error]} = Meta.run_refinements(ctx)
      assert Exception.message(error) == "Value is not an integer"
    end
  end

  describe "run_transforms/1" do
    test "runs transforms and returns the transformed value" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn input ->
          String.trim(input)
        end)
        |> Zoi.transform({Validation, :upcase, []})

      input = "   hello   "
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)

      assert {:ok, "HELLO"} == Meta.run_transforms(ctx)
    end

    test "runs transforms and returns the tuple for valid input" do
      schema = Zoi.string() |> Zoi.transform(fn _val -> {:ok, "random return"} end)
      input = "hello"
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)
      assert {:ok, "random return"} == Meta.run_transforms(ctx)
    end

    test "returns error for invalid transform" do
      schema = Zoi.string() |> Zoi.transform(fn _val -> {:error, "Transform failed"} end)
      input = "not a number"
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)
      assert {:error, [%Zoi.Error{} = error]} = Meta.run_transforms(ctx)
      assert Exception.message(error) == "Transform failed"
    end

    test "returns error for invalid transform using mfa" do
      schema = Zoi.string() |> Zoi.transform({Validation, :upcase, []})
      input = 12
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)
      assert {:error, [%Zoi.Error{} = error]} = Meta.run_transforms(ctx)
      assert Exception.message(error) == "Value is not a string"
    end

    test "accumulates errors from transforms" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _val -> {:error, "transform error 1"} end)
        |> Zoi.transform(fn _val -> {:error, "transform error 2"} end)

      input = "test"
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)
      assert {:error, [error_1, error_2]} = Meta.run_transforms(ctx)
      assert Exception.message(error_1) == "transform error 1"
      assert Exception.message(error_2) == "transform error 2"
    end

    test "return multiple errors from a single transform" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _val, ctx ->
          Zoi.Context.add_error(ctx, %{message: "transform error 1", path: [:test]})
          |> Zoi.Context.add_error("transform error 2")
        end)

      input = "test"
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)
      assert {:error, [error_1, error_2]} = Meta.run_transforms(ctx)
      assert Exception.message(error_1) == "transform error 1"
      assert Exception.message(error_2) == "transform error 2"
    end

    test "return multiple errors from a transform with mfa" do
      schema = Zoi.string() |> Zoi.transform({Validation, :upcase_error, []})

      input = 12
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)

      assert {:error, [error]} = Meta.run_transforms(ctx)
      assert Exception.message(error) == "Value is not a string"
    end
  end
end
